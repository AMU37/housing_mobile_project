/// إعدادات تطبيق إدارة السكن.
///
/// الوضع الافتراضي: العمل مع الخادم المشترك (server/server.js) بحيث تصل طلبات
/// المتعهدين إلى مراقب السكن على أجهزة مختلفة.
///
/// - عدّل [defaultBaseUrl] ليشير إلى عنوان الخادم الفعلي.
///   على جهاز أندرويد حقيقي استخدم عنوان حاسوب الخادم في الشبكة المحلية
///   (مثال: http://192.168.1.10:8080/api).
///   على محاكي أندرويد استخدم http://10.0.2.2:8080/api.
/// - يمكن تغيير العنوان داخل التطبيق من شاشة الدخول دون إعادة البناء
///   (يُحفظ على الجهاز)، ويُبقى كبديل في حال تعذّر الاتصال ويُعرض في الشاشة.
class AppConfig {
  AppConfig._();

  static const String appName = 'إدارة الشؤون | السكن';

  /// عنوان الخادم الافتراضي.
  ///
  /// يمكن ضبطه وقت البناء دون تعديل الكود:
  ///   flutter build apk --release --dart-define=HOUSING_API_BASE_URL=https://xxxx.onrender.com/api
  static const String defaultBaseUrl = String.fromEnvironment(
    'HOUSING_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  /// مفتاح تخزين عنوان الخادم المخصّص على الجهاز.
  static const String baseUrlPrefsKey = 'housing_api_base_url';

  static const Duration apiTimeout = Duration(seconds: 15);
}
