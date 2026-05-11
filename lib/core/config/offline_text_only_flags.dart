class OfflineTextOnlyFlags {
  const OfflineTextOnlyFlags._();

  static const bool enabled = true;

  static const String disabledTitle = 'Offline text-only mode';
  static const String disabledMessage =
      'This final build keeps offline communication focused on nearby text chat. '
      'Offline PTT, SOS, location sharing, and Live Radio are disabled until '
      'their physical-device delivery is fully verified.';
}
