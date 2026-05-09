enum TrendDirection {
  improving,
  stable,
  degrading,
  unknown,
}

extension TrendDirectionX on TrendDirection {
  static TrendDirection fromString(String value) {
    return TrendDirection.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TrendDirection.unknown,
    );
  }

  String get displayName {
    return switch (this) {
      TrendDirection.improving => 'Improving',
      TrendDirection.stable => 'Stable',
      TrendDirection.degrading => 'Degrading',
      TrendDirection.unknown => 'Unknown',
    };
  }
}
