enum SignalQualityLabel {
  excellent,
  good,
  fair,
  weak,
  lost,
}

extension SignalQualityLabelX on SignalQualityLabel {
  static SignalQualityLabel fromScore(double score) {
    if (score >= 80) return SignalQualityLabel.excellent;
    if (score >= 60) return SignalQualityLabel.good;
    if (score >= 40) return SignalQualityLabel.fair;
    if (score >= 20) return SignalQualityLabel.weak;
    return SignalQualityLabel.lost;
  }

  static SignalQualityLabel fromString(String value) {
    return SignalQualityLabel.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SignalQualityLabel.lost,
    );
  }

  String get displayName {
    return switch (this) {
      SignalQualityLabel.excellent => 'Excellent',
      SignalQualityLabel.good => 'Good',
      SignalQualityLabel.fair => 'Fair',
      SignalQualityLabel.weak => 'Weak',
      SignalQualityLabel.lost => 'Lost',
    };
  }
}
