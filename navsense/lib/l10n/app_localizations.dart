import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'NavSense'**
  String get appTitle;

  /// Bottom nav label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom nav label
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// Bottom nav label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Home screen heading
  ///
  /// In en, this message translates to:
  /// **'Select Destination'**
  String get homeSelectDestination;

  /// Floor label prefix
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get homeFloor;

  /// CTA button
  ///
  /// In en, this message translates to:
  /// **'Start Navigation'**
  String get homeStartNavigation;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Please select a destination'**
  String get homeNoDestination;

  /// Loading state
  ///
  /// In en, this message translates to:
  /// **'Computing route…'**
  String get homeComputingRoute;

  /// Beacon scanner page label
  ///
  /// In en, this message translates to:
  /// **'Beacon Scanner'**
  String get homeBeaconScanner;

  /// Starting room label
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get homeStartingFrom;

  /// Start room hint
  ///
  /// In en, this message translates to:
  /// **'Select start room'**
  String get homeSelectStartRoom;

  /// Feature badge label
  ///
  /// In en, this message translates to:
  /// **'Dijkstra Routing'**
  String get homeDijkstraFeature;

  /// Navigation page title
  ///
  /// In en, this message translates to:
  /// **'Navigating'**
  String get navigationHeading;

  /// Distance label
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get navigationDistanceLabel;

  /// Distance in meters
  ///
  /// In en, this message translates to:
  /// **'{distance} m'**
  String navigationMeters(String distance);

  /// BLE signal label
  ///
  /// In en, this message translates to:
  /// **'BLE Signal'**
  String get navigationBleSignal;

  /// BLE connected state
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get navigationBleConnected;

  /// BLE searching state
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get navigationBleDisconnected;

  /// Haptic label
  ///
  /// In en, this message translates to:
  /// **'Haptic'**
  String get navigationHapticLabel;

  /// Cancel navigation button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get navigationCancel;

  /// Step counter
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String navigationStepOf(int current, int total);

  /// Navigation page AppBar title
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navPageTitle;

  /// No route fallback message
  ///
  /// In en, this message translates to:
  /// **'No route available'**
  String get navNoRoute;

  /// OK button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get navOk;

  /// BLE beacon section header
  ///
  /// In en, this message translates to:
  /// **'BLE Beacon'**
  String get navBleBeacon;

  /// Signal strength label
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get navSignal;

  /// Beacon scanning status
  ///
  /// In en, this message translates to:
  /// **'Scanning for beacon…'**
  String get navScanningBeacon;

  /// Beacon proximity: very close
  ///
  /// In en, this message translates to:
  /// **'Very Close'**
  String get navStrengthVeryClose;

  /// Beacon proximity: close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get navStrengthClose;

  /// Beacon proximity: medium
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get navStrengthMedium;

  /// Beacon searching badge
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get navSearchingBadge;

  /// Route header with step count
  ///
  /// In en, this message translates to:
  /// **'Dijkstra Route  •  {count} steps'**
  String navDijkstraRoute(int count);

  /// Off-route action button
  ///
  /// In en, this message translates to:
  /// **'Off Route'**
  String get navOffRoute;

  /// Next step action button
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get navNextStep;

  /// Navigation instruction
  ///
  /// In en, this message translates to:
  /// **'Go straight'**
  String get instruction_go_straight;

  /// Navigation instruction
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get instruction_turn_left;

  /// Navigation instruction
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get instruction_turn_right;

  /// Navigation instruction
  ///
  /// In en, this message translates to:
  /// **'You have arrived!'**
  String get instruction_arrived;

  /// Off-route alert
  ///
  /// In en, this message translates to:
  /// **'Off route — recalculating…'**
  String get instruction_off_route;

  /// Navigation instruction: turn around
  ///
  /// In en, this message translates to:
  /// **'Turn Around'**
  String get instructionTurnAround;

  /// Haptic pattern label
  ///
  /// In en, this message translates to:
  /// **'Left pulse'**
  String get hapticLeft;

  /// Haptic pattern label
  ///
  /// In en, this message translates to:
  /// **'Double pulse'**
  String get hapticRight;

  /// Haptic pattern label
  ///
  /// In en, this message translates to:
  /// **'Long pulse'**
  String get hapticArrival;

  /// Haptic pattern label
  ///
  /// In en, this message translates to:
  /// **'Alert pulses'**
  String get hapticOffRoute;

  /// Simulation mode title
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get simTitle;

  /// Reset simulation button
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get simReset;

  /// Pause simulation button
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get simPause;

  /// Play simulation button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get simPlay;

  /// Arrived dialog: start over button
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get simStartOver;

  /// Floor plan section header
  ///
  /// In en, this message translates to:
  /// **'Floor Plan'**
  String get simFloorPlan;

  /// Next label in mobile metrics
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get simNext;

  /// Next turn metric label
  ///
  /// In en, this message translates to:
  /// **'Next Turn'**
  String get simNextTurn;

  /// Remaining distance label
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get simRemaining;

  /// ETA label
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get simEta;

  /// Empty route state in step progress
  ///
  /// In en, this message translates to:
  /// **'No route planned'**
  String get simNoRoute;

  /// Simulation controls section title
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get simControls;

  /// Speed slider label
  ///
  /// In en, this message translates to:
  /// **'Speed: {speed}x'**
  String simSpeed(String speed);

  /// Status indicator: running
  ///
  /// In en, this message translates to:
  /// **'Simulation Running'**
  String get simRunning;

  /// Legend: customer marker
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get simCustomer;

  /// Legend: destination marker
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get simDestinationLabel;

  /// Legend: route line
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get simRoute;

  /// Simulation state chip: idle
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get simStateIdle;

  /// Simulation state chip: origin set
  ///
  /// In en, this message translates to:
  /// **'Origin Set'**
  String get simStateOriginSet;

  /// Simulation state chip: route ready
  ///
  /// In en, this message translates to:
  /// **'Route Ready'**
  String get simStateRouteReady;

  /// Simulation state chip: navigating
  ///
  /// In en, this message translates to:
  /// **'Navigating'**
  String get simStateNavigating;

  /// Simulation state chip: paused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get simStatePaused;

  /// Simulation state chip: arrived
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get simStateArrived;

  /// Hint bar: idle state
  ///
  /// In en, this message translates to:
  /// **'Tap the map to set your start position'**
  String get simHintIdle;

  /// Hint bar: origin set
  ///
  /// In en, this message translates to:
  /// **'Now tap a destination room'**
  String get simHintOriginSet;

  /// Hint bar: route ready
  ///
  /// In en, this message translates to:
  /// **'Press Play to start the simulation'**
  String get simHintRouteReady;

  /// Hint bar: simulating
  ///
  /// In en, this message translates to:
  /// **'Simulating navigation…'**
  String get simHintSimulating;

  /// Hint bar: paused
  ///
  /// In en, this message translates to:
  /// **'Paused — press Play to continue'**
  String get simHintPaused;

  /// Hint bar: arrived
  ///
  /// In en, this message translates to:
  /// **'You have arrived!'**
  String get simHintArrived;

  /// UWB map page title
  ///
  /// In en, this message translates to:
  /// **'UWB Live Map'**
  String get uwbMapTitle;

  /// UWB connection status: connected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get uwbConnected;

  /// UWB connection status: searching
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get uwbSearching;

  /// UWB connection status: disconnected
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get uwbDisconnected;

  /// UWB connection status: error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get uwbStatusError;

  /// Snackbar when export log is empty
  ///
  /// In en, this message translates to:
  /// **'No accuracy data to export'**
  String get uwbNoAccuracyData;

  /// Export log button tooltip
  ///
  /// In en, this message translates to:
  /// **'Export Log'**
  String get uwbExportLog;

  /// Clear route button tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear Route'**
  String get uwbClearRoute;

  /// Calibration prompt
  ///
  /// In en, this message translates to:
  /// **'Start moving to calibrate direction'**
  String get uwbStartMoving;

  /// Direction instruction: go forward
  ///
  /// In en, this message translates to:
  /// **'Go forward'**
  String get uwbGoForward;

  /// Direction suffix: to destination
  ///
  /// In en, this message translates to:
  /// **'to destination'**
  String get uwbToDestination;

  /// Info bar: waiting for position
  ///
  /// In en, this message translates to:
  /// **'Waiting for UWB position…'**
  String get uwbWaiting;

  /// Info bar: tap to navigate hint
  ///
  /// In en, this message translates to:
  /// **'Tap a room on the map to navigate'**
  String get uwbTapToNavigate;

  /// Beacon scanner idle status
  ///
  /// In en, this message translates to:
  /// **'Press Start Scan to begin'**
  String get beaconPressToStart;

  /// Beacon scanner initialising status
  ///
  /// In en, this message translates to:
  /// **'Initialising…'**
  String get beaconInitialising;

  /// Beacon scanner not supported status
  ///
  /// In en, this message translates to:
  /// **'BLE not supported on this platform'**
  String get beaconNotSupported;

  /// Beacon scanner detected status
  ///
  /// In en, this message translates to:
  /// **'{count} beacon(s) detected!'**
  String beaconDetected(int count);

  /// Beacon scanner scanning status
  ///
  /// In en, this message translates to:
  /// **'Scanning… ({count} cycles)'**
  String beaconScanning(int count);

  /// Beacon scanner error status
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String beaconError(String message);

  /// Beacon scanner stopped status
  ///
  /// In en, this message translates to:
  /// **'Scan stopped'**
  String get beaconScanStopped;

  /// Beacon selection label
  ///
  /// In en, this message translates to:
  /// **'Select beacons to scan'**
  String get beaconSelectToScan;

  /// Scanning in progress label
  ///
  /// In en, this message translates to:
  /// **'Looking for beacons…'**
  String get beaconLookingFor;

  /// Stop scan button label
  ///
  /// In en, this message translates to:
  /// **'Stop Scan'**
  String get beaconStopScan;

  /// Start scan button label
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get beaconStartScan;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get settingsLanguageArabic;

  /// About section title
  ///
  /// In en, this message translates to:
  /// **'About NavSense'**
  String get settingsAbout;

  /// App version
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get settingsVersion;

  /// Short app description
  ///
  /// In en, this message translates to:
  /// **'Indoor navigation system with haptic wearable device.'**
  String get settingsDescription;

  /// Settings RTL indicator
  ///
  /// In en, this message translates to:
  /// **'Arabic active — RTL layout'**
  String get settingsArabicActive;

  /// Settings LTR indicator
  ///
  /// In en, this message translates to:
  /// **'English active — LTR layout'**
  String get settingsEnglishActive;

  /// Session history page title
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String get historyTitle;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No navigation sessions yet.'**
  String get historyEmpty;

  /// Session detail label
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get historySessionId;

  /// Events label
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get historyEvents;

  /// Duration label
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get historyDuration;

  /// Export button label
  ///
  /// In en, this message translates to:
  /// **'View JSON'**
  String get historyExportJson;

  /// Route calculation time label
  ///
  /// In en, this message translates to:
  /// **'Route calc'**
  String get historyRouteCalcMs;

  /// Refresh button tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get historyRefresh;

  /// Route calc detail with ms value
  ///
  /// In en, this message translates to:
  /// **'Route calculation: {ms} ms'**
  String historyRouteCalcDetail(int ms);

  /// Session JSON dialog title
  ///
  /// In en, this message translates to:
  /// **'Session JSON'**
  String get historySessionJson;

  /// Close dialog button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get historyClose;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Route error message
  ///
  /// In en, this message translates to:
  /// **'Failed to compute route.'**
  String get errorRouteComputation;

  /// BLE scan in progress
  ///
  /// In en, this message translates to:
  /// **'Searching for wearable…'**
  String get bleSearchingForDevice;

  /// BLE device discovered
  ///
  /// In en, this message translates to:
  /// **'Wearable found'**
  String get bleDeviceFound;

  /// BLE connecting state
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get bleConnecting;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
