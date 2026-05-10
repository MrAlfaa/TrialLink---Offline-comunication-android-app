const assert = require('node:assert/strict');
const { io } = require('socket.io-client');

const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:5001/api';
const socketBaseUrl = apiBaseUrl.replace(/\/api\/?$/, '');
const stamp = Date.now();

async function request(method, path, body, token) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
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
  return new Promise((resolve) => socket.once(eventName, resolve));
}

async function registerUser(label) {
  const response = await expectStatus(
    'POST',
    '/auth/register',
    {
      fullName: `Phase Nine ${label}`,
      email: `phase9.${label.toLowerCase()}.${stamp}@example.com`,
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
  const member = await registerUser('Member');
  const stranger = await registerUser('Stranger');

  const groupResponse = await expectStatus(
    'POST',
    '/groups',
    { groupName: 'Phase Nine SOS Team', description: 'Emergency smoke test' },
    owner.token,
    201,
  );
  const group = groupResponse.data.group;
  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, member.token, 200);

  const ownerSocket = await connectSocket(owner.token);
  const memberSocket = await connectSocket(member.token);
  ownerSocket.emit('join_group', { groupId: group.id });
  memberSocket.emit('join_group', { groupId: group.id });
  await waitFor(ownerSocket, 'group_joined');
  await waitFor(memberSocket, 'group_joined');

  const clientEventId = `sos-${stamp}`;
  const alertPromise = waitFor(memberSocket, 'emergency_alert');
  const created = await expectStatus(
    'POST',
    `/groups/${group.id}/emergency`,
    {
      clientEventId,
      alertType: 'sos',
      message: 'Need help from smoke test',
      location: {
        latitude: 6.9271,
        longitude: 79.8612,
        accuracy: 12,
        capturedAt: new Date().toISOString(),
      },
      createdAt: new Date().toISOString(),
    },
    owner.token,
    201,
  );
  assert.equal(created.data.event.clientEventId, clientEventId);
  assert.equal((await alertPromise).clientEventId, clientEventId);

  const duplicate = await expectStatus(
    'POST',
    `/groups/${group.id}/emergency`,
    { clientEventId, alertType: 'sos', message: 'Duplicate' },
    owner.token,
    200,
  );
  assert.equal(duplicate.data.event.clientEventId, clientEventId);

  const ackPromise = waitFor(ownerSocket, 'emergency_ack');
  const acked = await expectStatus(
    'POST',
    `/groups/${group.id}/emergency/${created.data.event.id}/ack`,
    { note: 'Received' },
    member.token,
    200,
  );
  assert.equal(acked.data.event.status, 'acknowledged');
  assert.equal((await ackPromise).eventId, created.data.event.id);

  const history = await expectStatus('GET', `/groups/${group.id}/emergency`, null, member.token, 200);
  assert.equal(history.data.events.some((event) => event.clientEventId === clientEventId), true);
  await expectStatus('GET', `/groups/${group.id}/emergency`, null, stranger.token, 404);

  ownerSocket.disconnect();
  memberSocket.disconnect();
  console.log('Phase 09 emergency smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
