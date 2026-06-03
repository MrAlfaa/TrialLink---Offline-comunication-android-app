import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mode/mode_controller.dart';
import 'trip_session_model.dart';
import 'trip_session_repository.dart';

final modeScopedActiveTripProvider = FutureProvider<TripSessionModel?>((ref) {
  final mode = ref.watch(effectiveModeProvider);
  return ref.read(tripSessionRepositoryProvider).getActiveTripForMode(mode);
});

final activeTripProvider = FutureProvider<TripSessionModel?>((ref) {
  return ref.watch(modeScopedActiveTripProvider.future);
});

final tripListProvider = FutureProvider<List<TripSessionModel>>((ref) {
  return ref.read(tripSessionRepositoryProvider).getTrips();
});
