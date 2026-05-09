const emergencyService = require('./emergency.service');
const { sendSuccess } = require('../../utils/response');
const {
  emitEmergencyAck,
  emitEmergencyAlert,
  emitEmergencyResolved,
} = require('../../socket/socket');

const createEmergency = async (req, res, next) => {
  try {
    const result = await emergencyService.createOrFindEmergency({
      groupId: req.params.groupId,
      userId: req.user._id,
      clientEventId: req.body.clientEventId,
      alertType: req.body.alertType,
      message: req.body.message,
      location: req.body.location,
      createdAt: req.body.createdAt,
      bridgeMetadata: emergencyService.bridgeFieldsFrom(req.body, req.user._id),
    });
    const event = emergencyService.toEmergencyDto(result.event);

    if (result.created) {
      emitEmergencyAlert(req.params.groupId, event);
    }

    return sendSuccess(
      res,
      result.created
        ? 'Emergency alert created successfully'
        : 'Emergency alert already exists',
      { data: { event } },
      result.created ? 201 : 200,
    );
  } catch (error) {
    next(error);
  }
};

const listEmergencies = async (req, res, next) => {
  try {
    const events = await emergencyService.listEmergencies({
      groupId: req.params.groupId,
      userId: req.user._id,
      status: req.query.status,
      limit: req.query.limit,
    });
    return sendSuccess(res, 'Emergency events fetched successfully', {
      data: { events },
    });
  } catch (error) {
    next(error);
  }
};

const acknowledgeEmergency = async (req, res, next) => {
  try {
    const event = await emergencyService.acknowledgeEmergency({
      groupId: req.params.groupId,
      eventId: req.params.eventId,
      userId: req.user._id,
      note: req.body.note,
    });
    emitEmergencyAck(req.params.groupId, {
      eventId: event.id,
      groupId: req.params.groupId,
      acknowledgedBy: {
        id: req.user._id.toString(),
        fullName: req.user.fullName,
      },
      acknowledgedAt: new Date().toISOString(),
    });
    return sendSuccess(res, 'Emergency alert acknowledged', {
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

const resolveEmergency = async (req, res, next) => {
  try {
    const event = await emergencyService.resolveEmergency({
      groupId: req.params.groupId,
      eventId: req.params.eventId,
      userId: req.user._id,
    });
    emitEmergencyResolved(req.params.groupId, {
      eventId: event.id,
      groupId: req.params.groupId,
      resolvedAt: new Date().toISOString(),
    });
    return sendSuccess(res, 'Emergency alert resolved', {
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  acknowledgeEmergency,
  createEmergency,
  listEmergencies,
  resolveEmergency,
};
