const assert = require('node:assert/strict');

const baseUrl = process.env.API_BASE_URL || 'http://localhost:5001/api';
const stamp = Date.now();

const owner = {
  fullName: 'Phase Two Owner',
  email: `phase2.owner.${stamp}@example.com`,
  password: 'Password@123',
  phoneNumber: '0771234567',
};

const member = {
  fullName: 'Phase Two Member',
  email: `phase2.member.${stamp}@example.com`,
  password: 'Password@123',
  phoneNumber: '0777654321',
};

async function request(method, path, body, token) {
  const response = await fetch(`${baseUrl}${path}`, {
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

async function run() {
  const registerOwner = await expectStatus('POST', '/auth/register', owner, null, 201);
  assert.equal(registerOwner.success, true);
  assert.ok(registerOwner.data.token);
  assert.equal(registerOwner.data.user.email, owner.email);
  assert.equal(registerOwner.data.user.passwordHash, undefined);

  const duplicate = await request('POST', '/auth/register', owner);
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.success, undefined);
  assert.equal(duplicate.data.success, false);

  const loginOwner = await expectStatus(
    'POST',
    '/auth/login',
    { email: owner.email, password: owner.password },
    null,
    200,
  );
  const ownerToken = loginOwner.data.token;
  assert.ok(ownerToken);

  await expectStatus('GET', '/auth/me', null, null, 401);
  const me = await expectStatus('GET', '/auth/me', null, ownerToken, 200);
  assert.equal(me.data.user.email, owner.email);

  const groupPayload = {
    groupName: 'Knuckles Hiking Team',
    description: 'Weekend camping group',
  };
  const createGroup = await expectStatus('POST', '/groups', groupPayload, ownerToken, 201);
  const group = createGroup.data.group;
  assert.match(group.groupCode, /^TL-[A-Z0-9]{5}$/);

  const ownerGroups = await expectStatus('GET', '/groups/my', null, ownerToken, 200);
  assert.ok(ownerGroups.data.groups.some((item) => item.id === group.id));

  const registerMember = await expectStatus('POST', '/auth/register', member, null, 201);
  const memberToken = registerMember.data.token;

  const join = await expectStatus(
    'POST',
    '/groups/join',
    { groupCode: group.groupCode },
    memberToken,
    200,
  );
  assert.equal(join.data.group.groupCode, group.groupCode);

  const duplicateJoin = await request(
    'POST',
    '/groups/join',
    { groupCode: group.groupCode },
    memberToken,
  );
  assert.equal(duplicateJoin.status, 409);

  const details = await expectStatus('GET', `/groups/${group.id}`, null, memberToken, 200);
  assert.equal(details.data.group.groupName, groupPayload.groupName);

  const members = await expectStatus('GET', `/groups/${group.id}/members`, null, ownerToken, 200);
  assert.equal(members.data.members.length >= 2, true);

  const missingGroup = await request('POST', '/groups/join', { groupCode: 'TL-XXXXX' }, memberToken);
  assert.equal(missingGroup.status, 404);

  console.log('Phase 02 API smoke test passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
