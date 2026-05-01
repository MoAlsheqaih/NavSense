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
  String get homeBeaconScanner => 'Beacon Scanner';

  @override
  String get homeStartingFrom => 'Starting from';

  @override
  String get homeSelectStartRoom => 'Select start room';

  @override
  String get homeDijkstraFeature => 'Dijkstra Routing';

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
  String get navPageTitle => 'Navigation';

  @override
  String get navNoRoute => 'No route available';

  @override
  String get navOk => 'OK';

  @override
  String get navBleBeacon => 'BLE Beacon';

  @override
  String get navSignal => 'Signal';

  @override
  String get navScanningBeacon => 'Scanning for beacon…';

  @override
  String get navStrengthVeryClose => 'Very Close';

  @override
  String get navStrengthClose => 'Close';

  @override
  String get navStrengthMedium => 'Medium';

  @override
  String get navSearchingBadge => 'Searching…';

  @override
  String navDijkstraRoute(int count) {
    return 'Dijkstra Route  •  $count steps';
  }

  @override
  String get navOffRoute => 'Off Route';

  @override
  String get navNextStep => 'Next Step';

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
  String get instructionTurnAround => 'Turn Around';

  @override
  String get hapticLeft => 'Left pulse';

  @override
  String get hapticRight => 'Double pulse';

  @override
  String get hapticArrival => 'Long pulse';

  @override
  String get hapticOffRoute => 'Alert pulses';

  @override
  String get simTitle => 'Simulation';

  @override
  String get simReset => 'Reset';

  @override
  String get simPause => 'Pause';

  @override
  String get simPlay => 'Play';

  @override
  String get simStartOver => 'Start Over';

  @override
  String get simFloorPlan => 'Floor Plan';

  @override
  String get simNext => 'Next';

  @override
  String get simNextTurn => 'Next Turn';

  @override
  String get simRemaining => 'Remaining';

  @override
  String get simEta => 'ETA';

  @override
  String get simNoRoute => 'No route planned';

  @override
  String get simControls => 'Controls';

  @override
  String simSpeed(String speed) {
    return 'Speed: ${speed}x';
  }

  @override
  String get simRunning => 'Simulation Running';

  @override
  String get simCustomer => 'Customer';

  @override
  String get simDestinationLabel => 'Destination';

  @override
  String get simRoute => 'Route';

  @override
  String get simStateIdle => 'Idle';

  @override
  String get simStateOriginSet => 'Origin Set';

  @override
  String get simStateRouteReady => 'Route Ready';

  @override
  String get simStateNavigating => 'Navigating';

  @override
  String get simStatePaused => 'Paused';

  @override
  String get simStateArrived => 'Arrived';

  @override
  String get simHintIdle => 'Tap the map to set your start position';

  @override
  String get simHintOriginSet => 'Now tap a destination room';

  @override
  String get simHintRouteReady => 'Press Play to start the simulation';

  @override
  String get simHintSimulating => 'Simulating navigation…';

  @override
  String get simHintPaused => 'Paused — press Play to continue';

  @override
  String get simHintArrived => 'You have arrived!';

  @override
  String get uwbMapTitle => 'UWB Live Map';

  @override
  String get uwbConnected => 'Connected';

  @override
  String get uwbSearching => 'Searching…';

  @override
  String get uwbDisconnected => 'Disconnected';

  @override
  String get uwbStatusError => 'Error';

  @override
  String get uwbNoAccuracyData => 'No accuracy data to export';

  @override
  String get uwbExportLog => 'Export Log';

  @override
  String get uwbClearRoute => 'Clear Route';

  @override
  String get uwbStartMoving => 'Start moving to calibrate direction';

  @override
  String get uwbGoForward => 'Go forward';

  @override
  String get uwbToDestination => 'to destination';

  @override
  String get uwbWaiting => 'Waiting for UWB position…';

  @override
  String get uwbTapToNavigate => 'Tap a room on the map to navigate';

  @override
  String get beaconPressToStart => 'Press Start Scan to begin';

  @override
  String get beaconInitialising => 'Initialising…';

  @override
  String get beaconNotSupported => 'BLE not supported on this platform';

  @override
  String beaconDetected(int count) {
    return '$count beacon(s) detected!';
  }

  @override
  String beaconScanning(int count) {
    return 'Scanning… ($count cycles)';
  }

  @override
  String beaconError(String message) {
    return 'Error: $message';
  }

  @override
  String get beaconScanStopped => 'Scan stopped';

  @override
  String get beaconSelectToScan => 'Select beacons to scan';

  @override
  String get beaconLookingFor => 'Looking for beacons…';

  @override
  String get beaconStopScan => 'Stop Scan';

  @override
  String get beaconStartScan => 'Start Scan';

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
  String get settingsArabicActive => 'Arabic active — RTL layout';

  @override
  String get settingsEnglishActive => 'English active — LTR layout';

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
  String get historyRefresh => 'Refresh';

  @override
  String historyRouteCalcDetail(int ms) {
    return 'Route calculation: $ms ms';
  }

  @override
  String get historySessionJson => 'Session JSON';

  @override
  String get historyClose => 'Close';

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
