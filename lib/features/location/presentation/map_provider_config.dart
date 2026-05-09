enum MapProviderType {
  googleMaps,
  openStreetMap,
  fallbackListOnly,
}

class MapProviderConfig {
  const MapProviderConfig._();

  static const providerName = String.fromEnvironment(
    'TRAILLINK_MAP_PROVIDER',
    defaultValue: 'openStreetMap',
  );

  static MapProviderType get current => fromName(providerName);

  static MapProviderType fromName(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'google' => MapProviderType.googleMaps,
      'googlemaps' => MapProviderType.googleMaps,
      'google_maps' => MapProviderType.googleMaps,
      'osm' => MapProviderType.openStreetMap,
      'openstreetmap' => MapProviderType.openStreetMap,
      'open_street_map' => MapProviderType.openStreetMap,
      'fallback' => MapProviderType.fallbackListOnly,
      'fallbacklistonly' => MapProviderType.fallbackListOnly,
      'fallback_list_only' => MapProviderType.fallbackListOnly,
      _ => MapProviderType.openStreetMap,
    };
  }
}

class TrailMapDefaults {
  const TrailMapDefaults._();

  static const sriLankaLatitude = 7.8731;
  static const sriLankaLongitude = 80.7718;
  static const countryZoom = 7.0;
  static const detailZoom = 15.0;
}
