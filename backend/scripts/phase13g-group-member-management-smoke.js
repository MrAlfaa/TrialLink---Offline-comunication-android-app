const assert = require('node:assert/strict');

const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:5001/api';
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

async function registerUser(label) {
  const body = {
    fullName: `Phase 13G ${label}`,
    email: `phase13g.${label.toLowerCase()}.${stamp}@example.com`,
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
  const admin = await registerUser('Admin');
  const member = await registerUser('Member');
  const regular = await registerUser('Regular');

  const groupResponse = await expectStatus(
    'POST',
    '/groups',
    {
      groupName: 'Phase 13G Member Team',
      description: 'Member management smoke test group',
    },
    owner.token,
    201,
  );
  const group = groupResponse.data.group;

  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, admin.token, 200);
  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, member.token, 200);
  await expectStatus('POST', '/groups/join', { groupCode: group.groupCode }, regular.token, 200);

  let membersResponse = await expectStatus(
    'GET',
    `/groups/${group.id}/members`,
    null,
    owner.token,
    200,
  );
  const members = membersResponse.data.members;
  const ownerMembership = members.find((item) => item.userId === owner.user.id);
  const adminMembership = members.find((item) => item.userId === admin.user.id);
  const memberMembership = members.find((item) => item.userId === member.user.id);
  const regularMembership = members.find((item) => item.userId === regular.user.id);
  assert.ok(ownerMembership);
  assert.ok(adminMembership);
  assert.ok(memberMembership);
  assert.ok(regularMembership);
  assert.equal(ownerMembership.membershipStatus, 'active');

  await expectStatus(
    'PATCH',
    `/groups/${group.id}/members/${adminMembership.id}/role`,
    { memberRole: 'admin' },
    owner.token,
    200,
  );

  await expectStatus(
    'DELETE',
    `/groups/${group.id}/members/${memberMembership.id}`,
    null,
    regular.token,
    403,
  );
  await expectStatus(
    'DELETE',
    `/groups/${group.id}/members/${ownerMembership.id}`,
    null,
    owner.token,
    400,
  );
  await expectStatus(
    'DELETE',
    `/groups/${group.id}/members/${regularMembership.id}`,
    null,
    admin.token,
    200,
  );
  await expectStatus('GET', `/groups/${group.id}/messages`, null, regular.token, 404);

  await expectStatus('POST', `/groups/${group.id}/leave`, null, member.token, 200);
  await expectStatus('GET', `/groups/${group.id}/messages`, null, member.token, 404);

  const leaveOwner = await request('POST', `/groups/${group.id}/leave`, null, owner.token);
  assert.equal(
    leaveOwner.status,
    400,
    `only owner leave should fail: ${JSON.stringify(leaveOwner.data)}`,
  );

  membersResponse = await expectStatus(
    'GET',
    `/groups/${group.id}/members`,
    null,
    owner.token,
    200,
  );
  const after = membersResponse.data.members;
  assert.equal(
    after.find((item) => item.userId === regular.user.id).membershipStatus,
    'removed',
  );
  assert.equal(
    after.find((item) => item.userId === member.user.id).membershipStatus,
    'left',
  );

  await expectStatus('DELETE', `/groups/${group.id}`, null, admin.token, 403);
  await expectStatus('DELETE', `/groups/${group.id}`, null, owner.token, 200);
  await expectStatus('GET', `/groups/${group.id}/messages`, null, admin.token, 404);

  const myGroupsAfterArchive = await expectStatus(
    'GET',
    '/groups/my',
    null,
    owner.token,
    200,
  );
  assert.equal(
    myGroupsAfterArchive.data.groups.some((item) => item.id === group.id),
    false,
  );

  const lateJoiner = await registerUser('LateJoiner');
  await expectStatus(
    'POST',
    '/groups/join',
    { groupCode: group.groupCode },
    lateJoiner.token,
    404,
  );

  console.log('Phase 13G group member management smoke passed.');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
