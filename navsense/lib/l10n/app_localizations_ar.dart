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
  String get homeBeaconScanner => 'ماسح المستشعرات';

  @override
  String get homeStartingFrom => 'الانطلاق من';

  @override
  String get homeSelectStartRoom => 'اختر غرفة البداية';

  @override
  String get homeDijkstraFeature => 'خوارزمية ديكسترا';

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
  String get navPageTitle => 'التنقل';

  @override
  String get navNoRoute => 'لا يوجد مسار متاح';

  @override
  String get navOk => 'موافق';

  @override
  String get navBleBeacon => 'مستشعر BLE';

  @override
  String get navSignal => 'الإشارة';

  @override
  String get navScanningBeacon => 'جاري البحث عن المستشعر…';

  @override
  String get navStrengthVeryClose => 'قريب جداً';

  @override
  String get navStrengthClose => 'قريب';

  @override
  String get navStrengthMedium => 'متوسط';

  @override
  String get navSearchingBadge => 'جاري البحث…';

  @override
  String navDijkstraRoute(int count) {
    return 'مسار ديكسترا  •  $count خطوات';
  }

  @override
  String get navOffRoute => 'خارج المسار';

  @override
  String get navNextStep => 'الخطوة التالية';

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
  String get instructionTurnAround => 'استدر';

  @override
  String get hapticLeft => 'نبضة يسار';

  @override
  String get hapticRight => 'نبضتان';

  @override
  String get hapticArrival => 'نبضة طويلة';

  @override
  String get hapticOffRoute => 'نبضات تنبيه';

  @override
  String get simTitle => 'المحاكاة';

  @override
  String get simReset => 'إعادة تعيين';

  @override
  String get simPause => 'إيقاف مؤقت';

  @override
  String get simPlay => 'تشغيل';

  @override
  String get simStartOver => 'البدء من جديد';

  @override
  String get simFloorPlan => 'مخطط الطابق';

  @override
  String get simNext => 'التالي';

  @override
  String get simNextTurn => 'المنعطف التالي';

  @override
  String get simRemaining => 'المتبقي';

  @override
  String get simEta => 'وقت الوصول';

  @override
  String get simNoRoute => 'لم يتم تخطيط مسار';

  @override
  String get simControls => 'أدوات التحكم';

  @override
  String simSpeed(String speed) {
    return 'السرعة: ${speed}x';
  }

  @override
  String get simRunning => 'المحاكاة تعمل';

  @override
  String get simCustomer => 'العميل';

  @override
  String get simDestinationLabel => 'الوجهة';

  @override
  String get simRoute => 'المسار';

  @override
  String get simStateIdle => 'في الانتظار';

  @override
  String get simStateOriginSet => 'تم تحديد نقطة البداية';

  @override
  String get simStateRouteReady => 'المسار جاهز';

  @override
  String get simStateNavigating => 'جاري التنقل';

  @override
  String get simStatePaused => 'متوقف مؤقتاً';

  @override
  String get simStateArrived => 'وصلت';

  @override
  String get simHintIdle => 'اضغط على الخريطة لتحديد موقع البداية';

  @override
  String get simHintOriginSet => 'الآن اضغط على غرفة الوجهة';

  @override
  String get simHintRouteReady => 'اضغط تشغيل لبدء المحاكاة';

  @override
  String get simHintSimulating => 'جاري محاكاة التنقل…';

  @override
  String get simHintPaused => 'متوقف — اضغط تشغيل للمتابعة';

  @override
  String get simHintArrived => 'لقد وصلت!';

  @override
  String get uwbMapTitle => 'خريطة UWB المباشرة';

  @override
  String get uwbConnected => 'متصل';

  @override
  String get uwbSearching => 'جاري البحث…';

  @override
  String get uwbDisconnected => 'غير متصل';

  @override
  String get uwbStatusError => 'خطأ';

  @override
  String get uwbNoAccuracyData => 'لا توجد بيانات دقة للتصدير';

  @override
  String get uwbExportLog => 'تصدير السجل';

  @override
  String get uwbClearRoute => 'مسح المسار';

  @override
  String get uwbStartMoving => 'ابدأ الحركة لمعايرة الاتجاه';

  @override
  String get uwbGoForward => 'تقدم للأمام';

  @override
  String get uwbToDestination => 'إلى الوجهة';

  @override
  String get uwbWaiting => 'في انتظار موقع UWB…';

  @override
  String get uwbTapToNavigate => 'اضغط على غرفة في الخريطة للتنقل';

  @override
  String get beaconPressToStart => 'اضغط \"بدء الفحص\" للبدء';

  @override
  String get beaconInitialising => 'جاري التهيئة…';

  @override
  String get beaconNotSupported => 'BLE غير مدعوم على هذه المنصة';

  @override
  String beaconDetected(int count) {
    return 'تم اكتشاف $count مستشعر!';
  }

  @override
  String beaconScanning(int count) {
    return 'جاري الفحص… ($count دورة)';
  }

  @override
  String beaconError(String message) {
    return 'خطأ: $message';
  }

  @override
  String get beaconScanStopped => 'توقف الفحص';

  @override
  String get beaconSelectToScan => 'اختر المستشعرات للفحص';

  @override
  String get beaconLookingFor => 'جاري البحث عن المستشعرات…';

  @override
  String get beaconStopScan => 'إيقاف الفحص';

  @override
  String get beaconStartScan => 'بدء الفحص';

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
  String get settingsArabicActive => 'العربية نشطة — تخطيط RTL';

  @override
  String get settingsEnglishActive => 'الإنجليزية نشطة — تخطيط LTR';

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
  String get historyRefresh => 'تحديث';

  @override
  String historyRouteCalcDetail(int ms) {
    return 'وقت حساب المسار: $ms م.ث';
  }

  @override
  String get historySessionJson => 'JSON الجلسة';

  @override
  String get historyClose => 'إغلاق';

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
