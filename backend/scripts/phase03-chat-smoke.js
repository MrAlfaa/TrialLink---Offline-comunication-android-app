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
  return new Promise((resolve) => {
    socket.once(eventName, resolve);
  });
}

async function registerUser(label) {
  const body = {
    fullName: `Phase Three ${label}`,
    email: `phase3.${label.toLowerCase()}.${stamp}@example.com`,
    password: 'Password@123',
    phoneNumber: '0771234567',
  };
  const response = await expectStatus('POST', '/auth/register', body, null, 201);
  return {
    user: response.data.user,
    token: response.data.token,
  };
}

async function run() {
  const owner = await registerUser('Owner');
  const member = await registerUser('Member');
  const stranger = await registerUser('Stranger');

  const groupResponse = await expectStatus(
    'POST',
    '/groups',
    {
      groupName: 'Phase Three Chat Team',
      description: 'Socket.IO smoke test group',
    },
    owner.token,
    201,
  );
  const group = groupResponse.data.group;

  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, member.token, 200);

  const ownerSocket = await connectSocket(owner.token);
  const memberSocket = await connectSocket(member.token);
  const strangerSocket = await connectSocket(stranger.token);

  const ownerJoined = waitFor(ownerSocket, 'group_joined');
  ownerSocket.emit('join_group', { groupId: group.id });
  assert.equal((await ownerJoined).groupId, group.id);

  const memberJoined = waitFor(memberSocket, 'group_joined');
  memberSocket.emit('join_group', { groupId: group.id });
  assert.equal((await memberJoined).groupId, group.id);

  const strangerError = waitFor(strangerSocket, 'socket_error');
  strangerSocket.emit('join_group', { groupId: group.id });
  assert.equal((await strangerError).code, 'NOT_GROUP_MEMBER');

  const clientMessageId = `smoke-${stamp}`;
  const ackPromise = waitFor(ownerSocket, 'message_sent_ack');
  const messagePromise = waitFor(memberSocket, 'new_group_message');
  ownerSocket.emit('send_group_message', {
    clientMessageId,
    groupId: group.id,
    content: 'Hello from Phase 03 smoke test',
    messageType: 'text',
    createdAt: new Date().toISOString(),
  });

  const ack = await ackPromise;
  assert.equal(ack.clientMessageId, clientMessageId);
  const received = await messagePromise;
  assert.equal(received.clientMessageId, clientMessageId);
  assert.equal(received.sender.email, owner.user.email);

  const history = await expectStatus('GET', `/groups/${group.id}/messages`, null, member.token, 200);
  assert.equal(
    history.data.messages.some((message) => message.clientMessageId === clientMessageId),
    true,
  );

  const sync = await expectStatus(
    'POST',
    `/groups/${group.id}/messages/sync`,
    {
      messages: [
        {
          clientMessageId,
          content: 'Hello from Phase 03 smoke test',
          messageType: 'text',
          createdAt: new Date().toISOString(),
        },
      ],
    },
    owner.token,
    200,
  );
  assert.equal(sync.data.syncedMessages[0].clientMessageId, clientMessageId);

  await expectStatus('GET', `/groups/${group.id}/messages`, null, stranger.token, 404);

  ownerSocket.disconnect();
  memberSocket.disconnect();
  strangerSocket.disconnect();

  console.log('Phase 03 chat smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
