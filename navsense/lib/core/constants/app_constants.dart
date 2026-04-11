class AppConstants {
  AppConstants._();

  static const String appName = 'NavSense';

  /// Simulated route computation delay (≤3 s per SRS Spec 10).
  static const Duration mockRouteDelay = Duration(milliseconds: 50);

  /// BLE scan interval for mock service.
  static const Duration bleScanInterval = Duration(seconds: 2);

  /// Distance update interval for mock BLE stream.
  static const Duration bleDistanceInterval = Duration(milliseconds: 500);

  /// Haptic trigger debounce period.
  static const Duration hapticDebounce = Duration(milliseconds: 200);

  /// SharedPreferences key for selected locale.
  static const String localeKey = 'navsense_locale';

  /// Mock BLE device name.
  static const String mockDeviceName = 'NavSense-Wearable';
}
