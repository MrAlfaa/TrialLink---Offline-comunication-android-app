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
      fullName: `Phase Ten ${label}`,
      email: `phase10.${label.toLowerCase()}.${stamp}@example.com`,
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
    { groupName: 'Phase Ten Location Team', description: 'Location smoke test' },
    owner.token,
    201,
  );
  const group = groupResponse.data.group;
  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, member.token, 200);

  const memberSocket = await connectSocket(member.token);
  memberSocket.emit('join_group', { groupId: group.id });
  await waitFor(memberSocket, 'group_joined');

  const clientLocationId = `loc-${stamp}`;
  const updatePromise = waitFor(memberSocket, 'location_update');
  const created = await expectStatus(
    'POST',
    `/groups/${group.id}/locations`,
    {
      clientLocationId,
      latitude: 6.9271,
      longitude: 79.8612,
      accuracy: 10,
      capturedAt: new Date().toISOString(),
    },
    owner.token,
    201,
  );
  assert.equal(created.data.location.clientLocationId, clientLocationId);
  assert.equal((await updatePromise).clientLocationId, clientLocationId);

  const sync = await expectStatus(
    'POST',
    `/groups/${group.id}/locations/sync`,
    {
      locations: [
        {
          clientLocationId,
          latitude: 6.9271,
          longitude: 79.8612,
          accuracy: 10,
          capturedAt: new Date().toISOString(),
        },
      ],
    },
    owner.token,
    200,
  );
  assert.equal(sync.data.locations[0].clientLocationId, clientLocationId);

  const latest = await expectStatus(
    'GET',
    `/groups/${group.id}/locations/latest`,
    null,
    member.token,
    200,
  );
  assert.equal(latest.data.locations.some((location) => location.clientLocationId === clientLocationId), true);
  await expectStatus('GET', `/groups/${group.id}/locations/latest`, null, stranger.token, 404);

  memberSocket.disconnect();
  console.log('Phase 10 location smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
