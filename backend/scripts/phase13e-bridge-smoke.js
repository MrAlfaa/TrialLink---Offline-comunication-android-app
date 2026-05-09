const assert = require('assert');

const messageService = require('../src/modules/messages/message.service');
const emergencyService = require('../src/modules/emergency/emergency.service');
const locationService = require('../src/modules/location/location.service');

const userId = '507f1f77bcf86cd799439011';
const bridgeBody = {
  sourcePath: 'bridge',
  originLocalId: 'guest_abc123',
  originDisplayName: 'Offline Guest',
  originIdentityType: 'guest',
  bridgedByLocalId: 'local_bridge_1',
  bridgedByName: 'Bridge Phone',
  bridgedAt: '2026-05-06T10:00:00.000Z',
  originalPacketId: 'packet-1',
  channelCode: 'TL-OFF-8K2P',
};

const messageFields = messageService.bridgeFieldsFrom(bridgeBody, userId);
const emergencyFields = emergencyService.bridgeFieldsFrom(bridgeBody, userId);
const locationFields = locationService.bridgeFieldsFrom(bridgeBody, userId);

for (const fields of [messageFields, emergencyFields, locationFields]) {
  assert.strictEqual(fields.sourcePath, 'bridge');
  assert.strictEqual(fields.originLocalId, 'guest_abc123');
  assert.strictEqual(fields.originDisplayName, 'Offline Guest');
  assert.strictEqual(fields.originIdentityType, 'guest');
  assert.strictEqual(fields.bridgedBy, userId);
  assert.strictEqual(fields.bridgedByLocalId, 'local_bridge_1');
  assert.strictEqual(fields.bridgedByName, 'Bridge Phone');
  assert.strictEqual(fields.originalPacketId, 'packet-1');
  assert.strictEqual(fields.channelCode, 'TL-OFF-8K2P');
}

const onlineFields = messageService.bridgeFieldsFrom({ sourcePath: 'online' }, userId);
assert.strictEqual(onlineFields.sourcePath, 'online');

console.log('Phase 13E bridge metadata smoke checks passed.');
