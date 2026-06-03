import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14Y mode scope, live audio, and voice UI contracts', () {
    test('trip repository stores separate active online and offline trips', () {
      final repository =
          File('lib/features/trip/data/trip_session_repository.dart')
              .readAsStringSync();
      final service =
          File('lib/features/trip_context/data/trip_context_service.dart')
              .readAsStringSync();

      expect(repository, contains('active_online_trip_id'));
      expect(repository, contains('active_offline_trip_id'));
      expect(repository,
          contains('Future<TripSessionModel?> getActiveTripForMode'));
      expect(repository, contains('Future<void> setActiveTripForMode'));
      expect(service, contains('getActiveTripContextForMode'));
      expect(service, contains('effectiveModeProvider'));
    });

    test('chat hub filters cloud and offline groups by effective mode', () {
      final hub = File('lib/features/chat/presentation/chat_hub_screen.dart')
          .readAsStringSync();

      expect(hub, contains('modeStateProvider'));
      expect(hub, contains('_MessageScope.online'));
      expect(hub, contains('_MessageScope.offline'));
      expect(hub, contains('_tabsForScope'));
      expect(hub, contains("'Online Groups'"));
      expect(hub, contains("'Offline Chats'"));
      expect(hub, contains('_openCreateForScope'));
      expect(hub, contains('_openJoinForScope'));
    });

    test('dashboard and mode switching use mode-scoped active trip context',
        () {
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();
      final sheet =
          File('lib/shared/widgets/mode_bottom_sheet.dart').readAsStringSync();

      expect(dashboard, contains('modeScopedActiveTripProvider'));
      expect(dashboard, contains('No offline trip is active'));
      expect(dashboard, contains('No online trip is active'));
      expect(sheet, contains("context.go('/home')"));
      expect(sheet, contains('modeScopedActiveTripProvider'));
      expect(sheet, contains('activeTripContextProvider'));
    });

    test('voice note bubble has persistent playback controls and progress', () {
      final bubble =
          File('lib/features/ptt/presentation/widgets/voice_note_bubble.dart')
              .readAsStringSync();
      final controller =
          File('lib/features/ptt/presentation/ptt_controller.dart')
              .readAsStringSync();

      expect(controller, contains('VoiceNotePlaybackState'));
      expect(controller, contains('playbackByNoteId'));
      expect(controller, contains('resetPlayback'));
      expect(controller, contains('connectedPeerCount'));
      expect(controller, contains('connectedPeerCount('));
      expect(controller, contains('clearStaleLiveRadioPeerMessage'));
      expect(controller, contains('clearInfoMessage'));
      expect(bubble, contains('LinearProgressIndicator'));
      expect(bubble, contains('Icons.pause_rounded'));
      expect(bubble, contains('Icons.play_arrow_rounded'));
      expect(bubble, contains('progress'));
      expect(bubble, contains('playbackState'));
    });

    test('live radio state machine releases floor without disconnecting Nearby',
        () {
      final controller =
          File('lib/features/ptt/presentation/ptt_controller.dart')
              .readAsStringSync();
      final repository =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();
      final liveAudio =
          File('lib/features/ptt/data/live_radio_audio_service.dart')
              .readAsStringSync();
      final pttButton =
          File('lib/features/ptt/presentation/widgets/push_to_talk_button.dart')
              .readAsStringSync();

      expect(controller, contains('enum LiveRadioUiState'));
      expect(controller, contains('LiveRadioUiState.releasing'));
      expect(controller, contains('LiveRadioUiState.idle'));
      expect(controller, contains('_liveReleaseRequestedDuringStart'));
      expect(controller, contains('RADIO_LOCK_REQUESTED'));
      expect(controller, contains('RADIO_LOCK_RELEASED'));
      expect(repository, contains('_endingLiveRadio'));
      expect(repository, contains('endLiveRadio'));
      expect(repository, contains('await _liveAudio.stopOutgoingStream();'));
      expect(repository, contains('await _liveAudio.stopIncomingStreams();'));
      expect(repository, contains('createLiveEndPacket'));
      expect(repository, isNot(contains('disconnectAllPeers(')));
      expect(liveAudio, contains('_feedQueue'));
      expect(liveAudio, contains('_safeFeedChunk'));
      expect(liveAudio, contains('_feeding'));
      expect(liveAudio, isNot(contains('unawaited(feed(next.bytes))')));
      expect(pttButton, contains('State<PushToTalkButton>'));
      expect(pttButton, contains('Listener('));
      expect(pttButton, contains('onPointerDown'));
      expect(pttButton, contains('onPointerUp'));
      expect(
        pttButton,
        contains('!widget.enabled && !widget.isRecording && !widget.isWaiting'),
      );
      expect(pttButton, isNot(contains('onTapDown')));
      expect(pttButton, isNot(contains('onLongPressStart')));
    });

    test('PTT peer chip uses live Nearby count instead of global mode count',
        () {
      final screen = File('lib/features/ptt/presentation/ptt_screen.dart')
          .readAsStringSync();
      final controller =
          File('lib/features/ptt/presentation/ptt_controller.dart')
              .readAsStringSync();
      final repository =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();

      expect(
          screen, contains('PeerStatusChip(count: state.connectedPeerCount)'));
      expect(
        screen,
        isNot(contains('PeerStatusChip(count: modeState.connectedPeerCount)')),
      );
      expect(controller, contains('await _repository.connectedPeerCount'));
      expect(repository, contains('Future<int> connectedPeerCount'));
    });
  });
}
