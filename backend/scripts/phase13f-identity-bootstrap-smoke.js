const assert = require('node:assert/strict');

const baseUrl = process.env.API_BASE_URL || 'http://localhost:5001/api';
const stamp = Date.now();

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

async function run() {
  const payload = {
    displayName: 'Phase 13F Explorer',
    email: `phase13f.${stamp}@example.com`,
    phoneNumber: '0771234567',
    emergencyNote: 'Blue jacket',
    localUserId: `local_${stamp}`,
    deviceId: `device_${stamp}`,
  };

  const created = await request('POST', '/identity/bootstrap', payload);
  assert.equal(
    created.status,
    201,
    `bootstrap expected 201: ${JSON.stringify(created.data)}`,
  );
  assert.equal(created.data.success, true);
  assert.ok(created.data.data.token);
  assert.equal(created.data.data.user.email, payload.email);
  assert.match(created.data.data.user.publicUserId, /^UID-\d{12}$/);
  assert.equal(created.data.data.user.localUserId, payload.localUserId);
  assert.equal(created.data.data.user.displayName, payload.displayName);
  assert.equal(created.data.data.user.emergencyNote, payload.emergencyNote);
  assert.equal(created.data.data.user.passwordHash, undefined);
  assert.equal(created.data.data.user.isBootstrapProfile, true);

  const token = created.data.data.token;
  const me = await request('GET', '/auth/me', null, token);
  assert.equal(me.status, 200);
  assert.equal(me.data.data.user.email, payload.email);

  const updated = await request('POST', '/identity/bootstrap', {
    ...payload,
    displayName: 'Phase 13F Explorer Updated',
  });
  assert.equal(updated.status, 201);
  assert.equal(updated.data.data.user.id, created.data.data.user.id);
  assert.equal(updated.data.data.user.fullName, 'Phase 13F Explorer');
  assert.equal(
    updated.data.data.user.publicUserId,
    created.data.data.user.publicUserId,
  );

  const conflict = await request('POST', '/identity/bootstrap', {
    ...payload,
    localUserId: `local_conflict_${stamp}`,
  });
  assert.equal(
    conflict.status,
    409,
    `email conflict expected 409: ${JSON.stringify(conflict.data)}`,
  );

  const noEmail = await request('POST', '/identity/bootstrap', {
    displayName: 'No Email Explorer',
    localUserId: `local_no_email_${stamp}`,
  });
  assert.equal(noEmail.status, 201);
  assert.equal(noEmail.data.data.user.email, null);
  assert.match(noEmail.data.data.user.publicUserId, /^UID-\d{12}$/);

  const invalid = await request('POST', '/identity/bootstrap', {
    displayName: 'A',
    email: 'invalid',
  });
  assert.equal(invalid.status, 422);

  console.log('Phase 13F identity bootstrap smoke passed');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
