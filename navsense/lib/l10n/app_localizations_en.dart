// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NavSense';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeSelectDestination => 'Select Destination';

  @override
  String get homeFloor => 'Floor';

  @override
  String get homeStartNavigation => 'Start Navigation';

  @override
  String get homeNoDestination => 'Please select a destination';

  @override
  String get homeComputingRoute => 'Computing route…';

  @override
  String get navigationHeading => 'Navigating';

  @override
  String get navigationDistanceLabel => 'Distance';

  @override
  String navigationMeters(String distance) {
    return '$distance m';
  }

  @override
  String get navigationBleSignal => 'BLE Signal';

  @override
  String get navigationBleConnected => 'Connected';

  @override
  String get navigationBleDisconnected => 'Searching…';

  @override
  String get navigationHapticLabel => 'Haptic';

  @override
  String get navigationCancel => 'Cancel';

  @override
  String navigationStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get instruction_go_straight => 'Go straight';

  @override
  String get instruction_turn_left => 'Turn left';

  @override
  String get instruction_turn_right => 'Turn right';

  @override
  String get instruction_arrived => 'You have arrived!';

  @override
  String get instruction_off_route => 'Off route — recalculating…';

  @override
  String get hapticLeft => 'Left pulse';

  @override
  String get hapticRight => 'Double pulse';

  @override
  String get hapticArrival => 'Long pulse';

  @override
  String get hapticOffRoute => 'Alert pulses';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'Arabic';

  @override
  String get settingsAbout => 'About NavSense';

  @override
  String get settingsVersion => 'Version 1.0.0';

  @override
  String get settingsDescription =>
      'Indoor navigation system with haptic wearable device.';

  @override
  String get historyTitle => 'Session History';

  @override
  String get historyEmpty => 'No navigation sessions yet.';

  @override
  String get historySessionId => 'Session ID';

  @override
  String get historyEvents => 'Events';

  @override
  String get historyDuration => 'Duration';

  @override
  String get historyExportJson => 'View JSON';

  @override
  String get historyRouteCalcMs => 'Route calc';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorRouteComputation => 'Failed to compute route.';

  @override
  String get bleSearchingForDevice => 'Searching for wearable…';

  @override
  String get bleDeviceFound => 'Wearable found';

  @override
  String get bleConnecting => 'Connecting…';
}
