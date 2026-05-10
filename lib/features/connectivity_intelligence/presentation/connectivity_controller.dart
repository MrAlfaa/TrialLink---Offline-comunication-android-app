import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../offline_channel/presentation/offline_channel_controller.dart';
import '../data/connectivity_intelligence_repository.dart';

class ConnectivityState {
  const ConnectivityState({
    this.summary,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final ConnectivityIntelligenceSummary? summary;
  final bool isRefreshing;
  final String? errorMessage;

  ConnectivityState copyWith({
    ConnectivityIntelligenceSummary? summary,
    bool? isRefreshing,
    String? errorMessage,
  }) {
    return ConnectivityState(
      summary: summary ?? this.summary,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
    );
  }
}

class ConnectivityController extends StateNotifier<ConnectivityState> {
  ConnectivityController(this.ref) : super(const ConnectivityState()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
  }

  final Ref ref;
  Timer? _timer;

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    try {
      final activeChannel =
          await ref.read(activeUsableOfflineChannelProvider.future);
      final summary =
          await connectivityIntelligenceRepository.summary(activeChannel);
      if (!mounted) return;
      state = ConnectivityState(summary: summary);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final connectivityControllerProvider = StateNotifierProvider.autoDispose<
    ConnectivityController, ConnectivityState>(
  ConnectivityController.new,
);
