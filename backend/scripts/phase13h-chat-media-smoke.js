const assert = require('node:assert/strict');
const { io } = require('socket.io-client');

const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:5001/api';
const socketBaseUrl = apiBaseUrl.replace(/\/api\/?$/, '');
const stamp = Date.now();

async function request(method, path, body, token) {
  const headers = {
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
  if (body && !(body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
  }
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers,
    body: body instanceof FormData ? body : body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json().catch(() => ({}));
  return { status: response.status, data };
}

async function expectStatus(method, path, body, token, status) {
  const result = await request(method, path, body, token);
  assert.equal(
    result.status,
    status,
    `${method} ${path} expected ${status}, received ${result.status}: ${JSON.stringify(result.data)}`,
  );
  return result.data;
}

function connectSocket(token) {
  return new Promise((resolve, reject) => {
    const socket = io(socketBaseUrl, {
      auth: { token },
      transports: ['websocket'],
      reconnection: false,
      timeout: 5000,
    });
    socket.on('connect', () => resolve(socket));
    socket.on('connect_error', reject);
  });
}

function waitFor(socket, eventName) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`Timed out waiting for ${eventName}`)),
      10000,
    );
    socket.once(eventName, (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

async function registerUser(label) {
  const response = await expectStatus(
    'POST',
    '/auth/register',
    {
      fullName: `Phase 13H ${label}`,
      email: `phase13h.${label.toLowerCase()}.${stamp}@example.com`,
      password: 'Password@123',
      phoneNumber: '0771234567',
    },
    null,
    201,
  );
  return { user: response.data.user, token: response.data.token };
}

function mediaForm({ clientMessageId, messageType, blob, fileName, durationMs }) {
  const form = new FormData();
  form.append('clientMessageId', clientMessageId);
  form.append('messageType', messageType);
  form.append('content', messageType === 'image' ? 'Image' : 'Voice note');
  form.append('createdAt', new Date().toISOString());
  if (durationMs != null) form.append('durationMs', String(durationMs));
  form.append('file', blob, fileName);
  return form;
}

async function run() {
  const owner = await registerUser('Owner');
  const member = await registerUser('Member');
  const stranger = await registerUser('Stranger');

  const groupResponse = await expectStatus(
    'POST',
    '/groups',
    { groupName: 'Phase 13H Media Team', description: 'Media smoke test' },
    owner.token,
    201,
  );
  const group = groupResponse.data.group;
  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, member.token, 200);

  const memberSocket = await connectSocket(member.token);
  const joined = waitFor(memberSocket, 'group_joined');
  memberSocket.emit('join_group', { groupId: group.id });
  await joined;

  const imageClientId = `image-${stamp}`;
  const imagePromise = waitFor(memberSocket, 'new_group_message');
  const image = await expectStatus(
    'POST',
    `/groups/${group.id}/messages/media`,
    mediaForm({
      clientMessageId: imageClientId,
      messageType: 'image',
      blob: new Blob([Buffer.from([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' }),
      fileName: 'trail.jpg',
    }),
    owner.token,
    201,
  );
  assert.equal(image.data.message.clientMessageId, imageClientId);
  assert.equal(image.data.message.messageType, 'image');
  assert.ok(image.data.message.mediaUrl.includes('/uploads/chat-media/'));
  assert.equal((await imagePromise).clientMessageId, imageClientId);

  const duplicate = await expectStatus(
    'POST',
    `/groups/${group.id}/messages/media`,
    mediaForm({
      clientMessageId: imageClientId,
      messageType: 'image',
      blob: new Blob([Buffer.from([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' }),
      fileName: 'trail.jpg',
    }),
    owner.token,
    200,
  );
  assert.equal(duplicate.data.message.clientMessageId, imageClientId);

  const voiceClientId = `voice-${stamp}`;
  const voicePromise = waitFor(memberSocket, 'new_group_message');
  const voice = await expectStatus(
    'POST',
    `/groups/${group.id}/messages/media`,
    mediaForm({
      clientMessageId: voiceClientId,
      messageType: 'voice',
      blob: new Blob([Buffer.from('fake-audio')], { type: 'audio/mp4' }),
      fileName: 'voice.m4a',
      durationMs: 1200,
    }),
    owner.token,
    201,
  );
  assert.equal(voice.data.message.messageType, 'voice');
  assert.equal((await voicePromise).clientMessageId, voiceClientId);

  await expectStatus(
    'POST',
    `/groups/${group.id}/messages/media`,
    mediaForm({
      clientMessageId: `bad-${stamp}`,
      messageType: 'file',
      blob: new Blob([Buffer.from('file')], { type: 'application/pdf' }),
      fileName: 'file.pdf',
    }),
    owner.token,
    422,
  );
  await expectStatus(
    'POST',
    `/groups/${group.id}/messages/media`,
    mediaForm({
      clientMessageId: `stranger-${stamp}`,
      messageType: 'image',
      blob: new Blob([Buffer.from([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' }),
      fileName: 'stranger.jpg',
    }),
    stranger.token,
    404,
  );

  const history = await expectStatus('GET', `/groups/${group.id}/messages`, null, member.token, 200);
  assert.equal(
    history.data.messages.some((message) => message.clientMessageId === imageClientId),
    true,
  );
  assert.equal(
    history.data.messages.some((message) => message.clientMessageId === voiceClientId),
    true,
  );

  memberSocket.disconnect();
  console.log('Phase 13H chat media smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
