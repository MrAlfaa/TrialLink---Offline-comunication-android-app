import 'location_repository.dart';

class LocationSyncService {
  LocationSyncService({LocationRepository? repository})
      : _repository = repository ?? LocationRepository();

  final LocationRepository _repository;

  Future<void> syncPendingLocations() {
    return _repository.syncPendingLocations();
  }
}
