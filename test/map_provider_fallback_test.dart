import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/location/data/models/location_update_model.dart';
import 'package:traillink/features/location/presentation/map_provider_config.dart';
import 'package:traillink/features/location/presentation/widgets/trail_map_card.dart';

void main() {
  test('map provider config parses supported provider names', () {
    expect(
      MapProviderConfig.fromName(null),
      MapProviderType.openStreetMap,
    );
    expect(
      MapProviderConfig.fromName('googleMaps'),
      MapProviderType.googleMaps,
    );
    expect(
      MapProviderConfig.fromName('osm'),
      MapProviderType.openStreetMap,
    );
    expect(
      MapProviderConfig.fromName('fallbackListOnly'),
      MapProviderType.fallbackListOnly,
    );
  });

  testWidgets('fallback map card never leaves users with a blank map',
      (tester) async {
    var usedCoordinateView = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrailMapCard(
            providerType: MapProviderType.fallbackListOnly,
            viewport: const TrailMapViewport(
              latitude: TrailMapDefaults.sriLankaLatitude,
              longitude: TrailMapDefaults.sriLankaLongitude,
              zoom: TrailMapDefaults.countryZoom,
            ),
            markers: const [],
            showCoordinateView: false,
            onRetry: () {},
            onUseCoordinateView: () => usedCoordinateView = true,
          ),
        ),
      ),
    );

    expect(find.text('Map unavailable'), findsOneWidget);
    expect(
      find.text(
          'Map tiles unavailable. Saved coordinates are still available.'),
      findsOneWidget,
    );
    expect(find.text('Retry Map'), findsOneWidget);
    expect(find.text('Use Coordinate View'), findsOneWidget);

    await tester.tap(find.text('Use Coordinate View'));
    expect(usedCoordinateView, isTrue);
  });

  testWidgets('coordinate card exposes saved location details', (tester) async {
    final capturedAt = DateTime(2026, 5, 9, 16, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoordinateLocationCard.fromOwnLocation(
            LocationUpdateModel(
              localLocationId: 'loc-1',
              userId: 'local-user',
              latitude: 7.8731,
              longitude: 80.7718,
              accuracy: 12.4,
              capturedAt: capturedAt,
              source: 'gps',
              shareStatus: 'local_only',
              syncState: 'local_only',
              createdAt: capturedAt,
            ),
          ),
        ),
      ),
    );

    expect(find.text('My location'), findsOneWidget);
    expect(find.text('7.873100, 80.771800'), findsOneWidget);
    expect(find.textContaining('Accuracy 12 m'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  test('map screen source uses fallback provider and updated helper text', () {
    final source = File('lib/features/location/presentation/map_screen.dart')
        .readAsStringSync();

    expect(source, contains('TrailMapCard'));
    expect(source, contains('TrailMapDefaults.sriLankaLatitude'));
    expect(
      source,
      contains(
        'Map tiles are loaded online. Saved teammate locations remain available offline.',
      ),
    );
    expect(
      source,
      contains(
        'Offline mode: map tiles may be unavailable, but saved coordinates and teammate cards remain available.',
      ),
    );
    expect(source,
        isNot(contains('Map tiles need internet unless already cached')));
  });

  test('teammate location query does not pass null whereArgs', () {
    final source =
        File('lib/features/location/data/location_local_data_source.dart')
            .readAsStringSync();

    expect(source, contains('List<Object?>? whereArgs'));
    expect(source, isNot(contains('whereArgs: [groupId ?? offlineChannelId]')));
  });
}
