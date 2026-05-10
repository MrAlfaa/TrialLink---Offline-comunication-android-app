const mongoose = require('mongoose');

const env = require('../src/config/env');
const ChatRoom = require('../src/models/chatRoom.model');
const EmergencyEvent = require('../src/models/emergencyEvent.model');
const Group = require('../src/models/group.model');
const GroupMember = require('../src/models/groupMember.model');
const LocationUpdate = require('../src/models/locationUpdate.model');
const Message = require('../src/models/message.model');
const Trip = require('../src/models/trip.model');
const TripChannel = require('../src/models/tripChannel.model');
const User = require('../src/models/user.model');
const VoiceNote = require('../src/models/voiceNote.model');

const argv = process.argv.slice(2);
const options = Object.fromEntries(
  argv
    .filter((arg) => arg.startsWith('--') && arg.includes('='))
    .map((arg) => {
      const [key, ...value] = arg.slice(2).split('=');
      return [key, value.join('=')];
    }),
);

const hasDeleteApproval = process.env.QA_ALLOW_DELETE === 'true';

const identityFilter = () => {
  const filters = [];
  if (options.email) filters.push({ email: options.email.toLowerCase() });
  if (options.phone) filters.push({ phoneNumber: options.phone });
  if (options.publicUserId) filters.push({ publicUserId: options.publicUserId });
  if (options.localUserId) {
    filters.push({ localUserId: options.localUserId });
    filters.push({ bootstrapLocalUserId: options.localUserId });
  }
  return filters.length === 1 ? filters[0] : filters.length > 1 ? { $or: filters } : null;
};

const count = async (Model, filter) => Model.countDocuments(filter);

const deleteOrCount = async (label, Model, filter) => {
  const matched = await count(Model, filter);
  if (!hasDeleteApproval) return { label, matched, deleted: 0 };
  const result = await Model.deleteMany(filter);
  return { label, matched, deleted: result.deletedCount || 0 };
};

const main = async () => {
  const filter = identityFilter();
  if (!filter) {
    throw new Error(
      'Provide one QA identity selector: --email=, --phone=, --publicUserId=, or --localUserId=.',
    );
  }
  if (!env.mongoUri) {
    throw new Error('MONGO_URI is required.');
  }

  await mongoose.connect(env.mongoUri);

  const users = await User.find(filter).select('_id email publicUserId localUserId phoneNumber');
  if (users.length === 0) {
    console.log('No matching QA user found. Nothing to clean.');
    return;
  }
  if (users.length > 1) {
    throw new Error(`Selector matched ${users.length} users. Use a more specific QA identity.`);
  }

  const user = users[0];
  const userId = user._id;
  const ownedGroups = await Group.find({ createdBy: userId }).select('_id groupName groupCode');
  const ownedGroupIds = ownedGroups.map((group) => group._id);

  const ownedGroupFilter = ownedGroupIds.length > 0 ? { groupId: { $in: ownedGroupIds } } : null;
  const userMessageFilter = {
    $or: [
      { senderId: userId },
      { originBackendId: userId },
      { bridgedBy: userId },
      ...(ownedGroupFilter ? [ownedGroupFilter] : []),
    ],
  };
  const userEmergencyFilter = {
    $or: [
      { senderId: userId },
      { originBackendId: userId },
      { bridgedBy: userId },
      ...(ownedGroupFilter ? [ownedGroupFilter] : []),
    ],
  };
  const userLocationFilter = {
    $or: [
      { userId },
      { originBackendId: userId },
      { bridgedBy: userId },
      ...(ownedGroupFilter ? [ownedGroupFilter] : []),
    ],
  };
  const userVoiceFilter = {
    $or: [{ senderId: userId }, ...(ownedGroupFilter ? [ownedGroupFilter] : [])],
  };
  const groupMemberFilter = {
    $or: [
      { userId },
      ...(ownedGroupIds.length > 0 ? [{ groupId: { $in: ownedGroupIds } }] : []),
    ],
  };

  const operations = [
    await deleteOrCount('messages', Message, userMessageFilter),
    await deleteOrCount('voiceNotes', VoiceNote, userVoiceFilter),
    await deleteOrCount('locationUpdates', LocationUpdate, userLocationFilter),
    await deleteOrCount('emergencyEvents', EmergencyEvent, userEmergencyFilter),
    await deleteOrCount('tripChannels', TripChannel, { ownerId: userId }),
    await deleteOrCount('chatRooms', ChatRoom, { ownerId: userId }),
    await deleteOrCount('trips', Trip, { ownerId: userId }),
    await deleteOrCount('groupMembers', GroupMember, groupMemberFilter),
    await deleteOrCount('ownedGroups', Group, { _id: { $in: ownedGroupIds } }),
    await deleteOrCount('users', User, { _id: userId }),
  ];

  const mode = hasDeleteApproval ? 'DELETE' : 'DRY RUN';
  console.log(`QA cleanup ${mode}`);
  console.log(
    JSON.stringify(
      {
        user: {
          id: userId.toString(),
          email: user.email,
          publicUserId: user.publicUserId,
          localUserId: user.localUserId,
          phoneNumber: user.phoneNumber,
        },
        ownedGroups: ownedGroups.map((group) => ({
          id: group._id.toString(),
          groupName: group.groupName,
          groupCode: group.groupCode,
        })),
        operations,
      },
      null,
      2,
    ),
  );

  if (!hasDeleteApproval) {
    console.log('Set QA_ALLOW_DELETE=true to perform the deletion after reviewing this dry run.');
  }
};

main()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
