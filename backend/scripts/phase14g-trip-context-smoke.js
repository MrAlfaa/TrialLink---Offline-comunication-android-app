const assert = require('node:assert/strict');

const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:5001/api';
const stamp = Date.now();

async function request(method, path, body, token) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
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

async function registerUser() {
  const response = await expectStatus(
    'POST',
    '/auth/register',
    {
      fullName: 'Phase 14G Owner',
      email: `phase14g.${stamp}@example.com`,
      password: 'Password@123',
      phoneNumber: '0771234567',
    },
    null,
    201,
  );
  return { user: response.data.user, token: response.data.token };
}

async function run() {
  const owner = await registerUser();
  const groupResponse = await expectStatus(
    'POST',
    '/groups',
    { groupName: 'Phase 14G Cloud Team', description: 'Trip context smoke' },
    owner.token,
    201,
  );
  const group = groupResponse.data.group;

  const firstPayload = {
    trips: [
      {
        tripId: `trip-a-${stamp}`,
        tripName: 'Phase 14G Trip A',
        status: 'active',
        mode: 'hybrid',
        activeChannelId: `channel-a-${stamp}`,
        cloudGroupId: group.id,
        lastOpenedAt: new Date().toISOString(),
      },
    ],
    channels: [
      {
        channelId: `channel-a-${stamp}`,
        tripId: `trip-a-${stamp}`,
        channelName: 'Main Team Channel',
        channelCode: `TL${String(stamp).slice(-6)}`,
        isPrimary: true,
        isActive: true,
        channelStatus: 'active',
      },
    ],
    chatRooms: [
      {
        chatId: `chat-a-${stamp}`,
        tripId: `trip-a-${stamp}`,
        channelId: `channel-a-${stamp}`,
        cloudGroupId: group.id,
        chatName: 'General',
        chatType: 'offline_channel',
        isDefault: true,
        isActive: true,
        chatStatus: 'active',
      },
    ],
  };

  const synced = await expectStatus('POST', '/trip-context/sync', firstPayload, owner.token, 200);
  assert.equal(synced.data.trips[0].tripId, firstPayload.trips[0].tripId);
  assert.equal(synced.data.channels[0].channelId, firstPayload.channels[0].channelId);
  assert.equal(synced.data.chatRooms[0].chatId, firstPayload.chatRooms[0].chatId);

  const duplicate = await expectStatus('POST', '/trip-context/sync', firstPayload, owner.token, 200);
  assert.equal(duplicate.data.trips.length, 1);
  assert.equal(duplicate.data.channels.length, 1);
  assert.equal(duplicate.data.chatRooms.length, 1);

  const switchPayload = {
    trips: [
      {
        tripId: `trip-b-${stamp}`,
        tripName: 'Phase 14G Trip B',
        status: 'active',
        mode: 'offline',
        activeChannelId: `channel-b-${stamp}`,
        lastOpenedAt: new Date(Date.now() + 1000).toISOString(),
      },
    ],
    channels: [
      {
        channelId: `channel-b-${stamp}`,
        tripId: `trip-b-${stamp}`,
        channelName: 'Backup Channel',
        channelCode: `TB${String(stamp).slice(-6)}`,
        isPrimary: true,
        isActive: true,
        channelStatus: 'active',
      },
    ],
    chatRooms: [
      {
        chatId: `chat-b-${stamp}`,
        tripId: `trip-b-${stamp}`,
        channelId: `channel-b-${stamp}`,
        chatName: 'General',
        chatType: 'offline_channel',
        isDefault: true,
        isActive: true,
        chatStatus: 'active',
      },
    ],
  };
  await expectStatus('POST', '/trip-context/sync', switchPayload, owner.token, 200);

  const pull = await expectStatus('GET', '/trip-context/sync', null, owner.token, 200);
  const tripA = pull.data.trips.find((trip) => trip.tripId === firstPayload.trips[0].tripId);
  const tripB = pull.data.trips.find((trip) => trip.tripId === switchPayload.trips[0].tripId);
  assert.equal(tripA.status, 'inactive');
  assert.equal(tripB.status, 'active');

  const messageClientId = `msg-${stamp}`;
  const messageSync = await expectStatus(
    'POST',
    `/groups/${group.id}/messages/sync`,
    {
      messages: [
        {
          clientMessageId: messageClientId,
          content: 'Trip context message',
          messageType: 'text',
          createdAt: new Date().toISOString(),
          tripId: firstPayload.trips[0].tripId,
          channelId: firstPayload.channels[0].channelId,
          chatId: firstPayload.chatRooms[0].chatId,
        },
      ],
    },
    owner.token,
    200,
  );
  assert.equal(messageSync.data.syncedMessages[0].clientMessageId, messageClientId);

  const history = await expectStatus('GET', `/groups/${group.id}/messages`, null, owner.token, 200);
  const syncedMessage = history.data.messages.find(
    (message) => message.clientMessageId === messageClientId,
  );
  assert.equal(syncedMessage.tripId, firstPayload.trips[0].tripId);
  assert.equal(syncedMessage.channelId, firstPayload.channels[0].channelId);
  assert.equal(syncedMessage.chatId, firstPayload.chatRooms[0].chatId);

  console.log('Phase 14G trip context smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
