import '../../../offline_channel/data/models/offline_channel_model.dart';
import '../../../trip/data/trip_session_model.dart';
import 'chat_room_model.dart';

class ActiveTripContext {
  const ActiveTripContext({
    required this.trip,
    this.activeChannel,
    this.activeChat,
  });

  final TripSessionModel trip;
  final OfflineChannelModel? activeChannel;
  final ChatRoomModel? activeChat;

  String? get cloudGroupId => trip.cloudGroupId;
  String? get channelCode => activeChannel?.channelCode ?? trip.channelCode;
  String get mode => trip.mode;
  bool get isCloudReady => (cloudGroupId ?? '').isNotEmpty;
  bool get isOfflineReady => activeChannel?.isUsable == true;
}
