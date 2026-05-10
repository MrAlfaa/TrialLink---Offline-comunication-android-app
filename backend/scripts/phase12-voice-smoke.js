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
      fullName: `Phase Twelve ${label}`,
      email: `phase12.${label.toLowerCase()}.${stamp}@example.com`,
      password: 'Password@123',
      phoneNumber: '0771234567',
    },
    null,
    201,
  );
  return { user: response.data.user, token: response.data.token };
}

async function run() {
  const owner = await registerUser('Owner');
  console.log('Owner registered');
  const member = await registerUser('Member');
  console.log('Member registered');
  const stranger = await registerUser('Stranger');
  console.log('Stranger registered');

  const groupResponse = await expectStatus(
    'POST',
    '/groups',
    { groupName: 'Phase Twelve Voice Team', description: 'Voice smoke test' },
    owner.token,
    201,
  );
  const group = groupResponse.data.group;
  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, member.token, 200);

  const ownerSocket = await connectSocket(owner.token);
  const memberSocket = await connectSocket(member.token);
  const ownerJoinedPromise = waitFor(ownerSocket, 'group_joined');
  const memberJoinedPromise = waitFor(memberSocket, 'group_joined');
  ownerSocket.emit('join_group', { groupId: group.id });
  memberSocket.emit('join_group', { groupId: group.id });
  await ownerJoinedPromise;
  await memberJoinedPromise;
  console.log('Sockets joined group');

  const grantedPromise = waitFor(ownerSocket, 'ptt_granted');
  const speakerPromise = waitFor(memberSocket, 'ptt_speaker_changed');
  ownerSocket.emit('ptt_request', {
    groupId: group.id,
    clientRequestId: `req-${stamp}`,
    requestedAt: new Date().toISOString(),
  });
  assert.equal((await grantedPromise).speakerId, owner.user.id);
  assert.equal((await speakerPromise).speakerId, owner.user.id);
  console.log('PTT grant verified');

  const deniedPromise = waitFor(memberSocket, 'ptt_denied');
  memberSocket.emit('ptt_request', {
    groupId: group.id,
    clientRequestId: `denied-${stamp}`,
    requestedAt: new Date().toISOString(),
  });
  assert.equal((await deniedPromise).currentSpeakerId, owner.user.id);
  console.log('PTT denial verified');

  const releasePromise = waitFor(memberSocket, 'ptt_speaker_released');
  ownerSocket.emit('ptt_release', { groupId: group.id, releasedAt: new Date().toISOString() });
  assert.equal((await releasePromise).speakerId, owner.user.id);
  console.log('PTT release verified');

  const form = new FormData();
  const clientVoiceId = `voice-${stamp}`;
  form.append('clientVoiceId', clientVoiceId);
  form.append('durationMs', '1200');
  form.append('createdAt', new Date().toISOString());
  form.append('audio', new Blob([Buffer.from('fake-audio')], { type: 'audio/mp4' }), 'voice.m4a');

  const voicePromise = waitFor(memberSocket, 'voice_note_received');
  const uploaded = await expectStatus('POST', `/groups/${group.id}/voice-notes`, form, owner.token, 201);
  assert.equal(uploaded.data.voiceNote.clientVoiceId, clientVoiceId);
  assert.equal((await voicePromise).clientVoiceId, clientVoiceId);
  console.log('Voice upload event verified');

  const duplicateForm = new FormData();
  duplicateForm.append('clientVoiceId', clientVoiceId);
  duplicateForm.append('durationMs', '1200');
  duplicateForm.append('audio', new Blob([Buffer.from('fake-audio')], { type: 'audio/mp4' }), 'voice.m4a');
  const duplicate = await expectStatus(
    'POST',
    `/groups/${group.id}/voice-notes`,
    duplicateForm,
    owner.token,
    200,
  );
  assert.equal(duplicate.data.voiceNote.clientVoiceId, clientVoiceId);

  const history = await expectStatus('GET', `/groups/${group.id}/voice-notes`, null, member.token, 200);
  assert.equal(history.data.voiceNotes.some((note) => note.clientVoiceId === clientVoiceId), true);
  await expectStatus('GET', `/groups/${group.id}/voice-notes`, null, stranger.token, 404);

  ownerSocket.disconnect();
  memberSocket.disconnect();
  console.log('Phase 12 voice smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
