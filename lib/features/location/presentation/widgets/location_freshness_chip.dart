import 'package:flutter/material.dart';

import '../../data/models/location_freshness.dart';

class LocationFreshnessChip extends StatelessWidget {
  const LocationFreshnessChip({
    required this.freshness,
    super.key,
  });

  final LocationFreshness freshness;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.circle, size: 10, color: freshness.color),
      label: Text(freshness.label),
    );
  }
}
