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
