import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trip_context/data/trip_context_service.dart';
import 'trip_session_model.dart';
import 'trip_session_repository.dart';

final activeTripProvider = FutureProvider<TripSessionModel?>((ref) {
  return ref.watch(activeTripContextProvider.future).then(
        (context) => context?.trip,
      );
});

final tripListProvider = FutureProvider<List<TripSessionModel>>((ref) {
  return ref.read(tripSessionRepositoryProvider).getTrips();
});
