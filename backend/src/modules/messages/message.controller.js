const messageService = require('./message.service');
const { sendSuccess } = require('../../utils/response');
const { emitGroupMessage } = require('../../socket/socket');

const getGroupMessages = async (req, res, next) => {
  try {
    const result = await messageService.getMessages({
      groupId: req.params.groupId,
      userId: req.user._id,
      page: req.query.page,
      limit: req.query.limit,
      before: req.query.before,
    });

    return sendSuccess(res, 'Messages fetched successfully', { data: result });
  } catch (error) {
    next(error);
  }
};

const syncGroupMessages = async (req, res, next) => {
  try {
    const result = await messageService.syncMessages({
      groupId: req.params.groupId,
      userId: req.user._id,
      messages: req.body.messages,
    });

    for (const message of result.createdMessages) {
      emitGroupMessage(req.params.groupId, message);
    }

    return sendSuccess(res, 'Messages synced successfully', {
      data: { syncedMessages: result.syncedMessages },
    });
  } catch (error) {
    next(error);
  }
};

const uploadMediaMessage = async (req, res, next) => {
  try {
    const result = await messageService.saveMediaMessage({
      groupId: req.params.groupId,
      userId: req.user._id,
      body: req.body,
      file: req.file,
    });

    if (result.created) {
      emitGroupMessage(req.params.groupId, result.dto);
    }

    return sendSuccess(
      res,
      result.created ? 'Media message uploaded successfully' : 'Media message already exists',
      { data: { message: result.dto } },
      result.created ? 201 : 200,
    );
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getGroupMessages,
  syncGroupMessages,
  uploadMediaMessage,
};
