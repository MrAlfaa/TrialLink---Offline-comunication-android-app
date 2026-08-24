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

async function registerUser(label) {
  const response = await expectStatus(
    'POST',
    '/auth/register',
    {
      fullName: `Phase 14J ${label}`,
      email: `phase14j.${label}.${stamp}@example.com`,
      password: 'Password@123',
      phoneNumber: '0771234567',
    },
    null,
    201,
  );
  return { user: response.data.user, token: response.data.token };
}

function assertNoRawMac(value) {
  const serialized = JSON.stringify(value);
  assert.equal(serialized.includes('bluetoothMac'), false);
  assert.equal(serialized.includes('macAddress'), false);
}

async function run() {
  const owner = await registerUser('owner');
  const member = await registerUser('member');

  const created = await expectStatus(
    'POST',
    '/trip-context/cloud-prepared-trips',
    {
      tripName: 'Phase 14J Cloud Prepared Trip',
      description: 'Cloud prepared offline fallback smoke',
      localUserId: 'local-owner-14j',
      appDeviceId: `device-owner-${stamp}`,
      capabilities: {
        supportsNearby: true,
        supportsPtt: true,
        supportsLiveRadio: false,
      },
    },
    owner.token,
    201,
  );
  const createdData = created.data;
  assert.equal(createdData.offlineBackupReady, true);
  assert.ok(createdData.trip.tripId);
  assert.ok(createdData.channel.channelId);
  assert.ok(createdData.chatRoom.chatId);
  assert.match(createdData.group.groupCode, /^TL-ONLI-[A-Z0-9]{5}$/);
  assert.equal(createdData.trip.primaryChannelId, createdData.channel.channelId);
  assert.equal(createdData.channel.channelCode, createdData.group.groupCode);
  assert.equal(createdData.roster.length, 1);
  assert.equal(createdData.roster[0].appDeviceId, `device-owner-${stamp}`);
  assertNoRawMac(createdData);

  const joined = await expectStatus(
    'POST',
    '/trip-context/cloud-prepared-trips/join',
    {
      tripCode: createdData.group.groupCode,
      localUserId: 'local-member-14j',
      appDeviceId: `device-member-${stamp}`,
      capabilities: {
        supportsNearby: true,
        supportsPtt: false,
        supportsLiveRadio: false,
      },
    },
    member.token,
    200,
  );
  const joinedData = joined.data;
  assert.equal(joinedData.trip.tripId, createdData.trip.tripId);
  assert.equal(joinedData.channel.channelId, createdData.channel.channelId);
  assert.equal(joinedData.chatRoom.chatId, createdData.chatRoom.chatId);
  assert.equal(joinedData.channel.channelCode, createdData.channel.channelCode);
  assert.equal(joinedData.roster.length, 2);
  assertNoRawMac(joinedData);

  const metadata = await expectStatus(
    'GET',
    `/trip-context/cloud-prepared-trips/${createdData.trip.tripId}/metadata`,
    null,
    member.token,
    200,
  );
  assert.equal(metadata.data.trip.tripId, createdData.trip.tripId);
  assert.equal(metadata.data.roster.length, 2);

  console.log('Phase 14J cloud-prepared metadata smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
