// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'NavSense';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navHistory => 'السجل';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get homeSelectDestination => 'اختر وجهتك';

  @override
  String get homeFloor => 'الطابق';

  @override
  String get homeStartNavigation => 'ابدأ التنقل';

  @override
  String get homeNoDestination => 'يرجى اختيار وجهة';

  @override
  String get homeComputingRoute => 'جاري حساب المسار…';

  @override
  String get navigationHeading => 'جاري التنقل';

  @override
  String get navigationDistanceLabel => 'المسافة';

  @override
  String navigationMeters(String distance) {
    return '$distance م';
  }

  @override
  String get navigationBleSignal => 'إشارة BLE';

  @override
  String get navigationBleConnected => 'متصل';

  @override
  String get navigationBleDisconnected => 'جاري البحث…';

  @override
  String get navigationHapticLabel => 'اهتزاز';

  @override
  String get navigationCancel => 'إلغاء';

  @override
  String navigationStepOf(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get instruction_go_straight => 'استمر للأمام';

  @override
  String get instruction_turn_left => 'انعطف يساراً';

  @override
  String get instruction_turn_right => 'انعطف يميناً';

  @override
  String get instruction_arrived => 'لقد وصلت!';

  @override
  String get instruction_off_route => 'خارج المسار — جاري إعادة الحساب…';

  @override
  String get hapticLeft => 'نبضة يسار';

  @override
  String get hapticRight => 'نبضتان';

  @override
  String get hapticArrival => 'نبضة طويلة';

  @override
  String get hapticOffRoute => 'نبضات تنبيه';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageEnglish => 'الإنجليزية';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsAbout => 'حول NavSense';

  @override
  String get settingsVersion => 'الإصدار 1.0.0';

  @override
  String get settingsDescription =>
      'نظام تنقل داخلي مع جهاز اهتزازي قابل للارتداء.';

  @override
  String get historyTitle => 'سجل الجلسات';

  @override
  String get historyEmpty => 'لا توجد جلسات تنقل بعد.';

  @override
  String get historySessionId => 'معرّف الجلسة';

  @override
  String get historyEvents => 'الأحداث';

  @override
  String get historyDuration => 'المدة';

  @override
  String get historyExportJson => 'عرض JSON';

  @override
  String get historyRouteCalcMs => 'وقت حساب المسار';

  @override
  String get errorGeneric => 'حدث خطأ. يرجى المحاولة مرة أخرى.';

  @override
  String get errorRouteComputation => 'فشل في حساب المسار.';

  @override
  String get bleSearchingForDevice => 'جاري البحث عن الجهاز…';

  @override
  String get bleDeviceFound => 'تم العثور على الجهاز';

  @override
  String get bleConnecting => 'جاري الاتصال…';
}
