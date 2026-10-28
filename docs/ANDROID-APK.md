# بناء تطبيق أندرويد (APK)

## 1) المعطيات

| العنصر | القيمة |
| --- | --- |
| معرّف التطبيق | `com.ycs.housing` |
| اسم التطبيق | نظام السكن |
| Capacitor | 8.5.x |
| compileSdk / targetSdk | 36 |
| minSdk | 24 (أندرويد 7.0+) |
| نسخة التطبيق | 2.0.0 (versionCode 2) |
| مجلد الويب | `frontend/dist` |

## 2) المتطلبات

- Android Studio أحدث إصدار + Android SDK 36 (Platform + Build-Tools).
- JDK المرفق مع Android Studio: `C:\Program Files\Android\Android Studio\jbr`.
- متغير `JAVA_HOME` مضبوط، أو يتولى السكربت اكتشافه.

## 3) بناء سريع

```powershell
cd D:\ali\housing_mobile_android_project\housing-management-system
.\scripts\build-apk.ps1
```

السكربت ينفّذ:
1. `npm run build` لبناء الواجهة إلى `frontend/dist`.
2. `npx cap sync android` لنسخ الأصول وتحديث الإضافات.
3. `gradlew assembleDebug` لبناء APK.
4. نسخ الناتج إلى `housing-management-v2.0.0.apk` في جذر المشروع.

### يدوياً

```powershell
cd frontend
npm run build
npx cap sync android
cd android
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
.\gradlew.bat assembleDebug
```

الناتج:
```
frontend\android\app\build\outputs\apk\debug\app-debug.apk
```

## 4) رابط الخادم داخل التطبيق

- صفحة الدخول فيها زر **«إعدادات الخادم»** لإدخال الرابط وحفظه على الجهاز، ويُفتح
  تلقائياً على أندرويد عند عدم وجود رابط مضبوط.
- يمكن تعديل الرابط لاحقاً من **الإعدادات → التطبيق والعمل دون إنترنت**.
- يُحفظ الرابط في `localStorage` (المفتاح `hs_config`).
- لتثبيت رابط افتراضي وقت البناء:

```powershell
cd frontend
$env:NEXT_PUBLIC_API_URL = "https://housing-management-api.onrender.com"
npm run build
npx cap sync android
```

> التطبيق يستخدم HTTPS افتراضياً. للاختبار على شبكة محلية عبر HTTP،
> `usesCleartextTraffic` مفعّل حالياً في `AndroidManifest.xml`.

## 5) المزايا الأصلية (JS Bridge)

الواجهة تستدعي `window.HousingApp` المتاح من `MainActivity.java`:

| الدالة | الوظيفة |
| --- | --- |
| `printHtml(name, html)` | طباعة كشف/تقرير عبر نافذة طباعة أندرويد (A4) |
| `openFile(name, mime, base64)` | حفظ ملف Excel/PDF في الكاش وفتحه بتطبيق خارجي |
| `shareText(subject, text)` | مشاركة نص عبر تطبيقات الجهاز |
| `notify(message)` | رسالة Toast |
| `canPrint()` | يعيد `true` |

هذه الدوال تُستخدم تلقائياً من `lib/export.ts` على أندرويد فقط، وتعود الواجهة إلى
التنزيل العادي على الويب.

## 6) العمل دون إنترنت

- بعد أول دخول ناجح تُحفظ نسخة من `bootstrap` في `localStorage`.
- يمكن ضبط رمز PIN (4 أرقام) للدخول المحلي عند انقطاع الشبكة.
- الوضع دون إنترنت **للقراءة فقط**: لا تُرسل تعديلات، وتظهر رسالة واضحة.
- تسجيل الخروج يمسح الجلسة المحلية والنسخة المحفوظة.

## 7) توقيع نسخة الإصدار (Release)

1. أنشئ مفتاح توقيع:

```powershell
keytool -genkeypair -v -keystore housing-release.jks -alias housing `
  -keyalg RSA -keysize 2048 -validity 10000
```

2. أضف إلى `frontend\android\app\build.gradle` داخل `android {}`:

```gradle
signingConfigs {
    release {
        storeFile file("../../housing-release.jks")
        storePassword System.getenv("HOUSING_STORE_PASSWORD")
        keyAlias "housing"
        keyPassword System.getenv("HOUSING_KEY_PASSWORD")
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled false
    }
}
```

3. ابنِ:

```powershell
cd frontend\android
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:HOUSING_STORE_PASSWORD = "…"
$env:HOUSING_KEY_PASSWORD = "…"
.\gradlew.bat assembleRelease
```

الناتج: `app\build\outputs\apk\release\app-release.apk`

> لا تضع ملف `.jks` أو كلمات المرور في Git. أضفهما إلى `.gitignore`.

## 8) تحديث التطبيق بعد تغيير الواجهة

كل تغيير في الواجهة يتطلب إعادة البناء:

```powershell
cd frontend
npm run build
npx cap sync android
cd android; .\gradlew.bat assembleDebug
```

> `npx cap copy android` كافٍ لنسخ الأصول دون تحديث الإضافات، لكن `sync` هو الآمن.

## 9) حل المشكلات

### Gradle يحاول تنزيل إصدار ولا يكتمل
- المشروع مضبوط على Gradle **8.13** (متوافق مع AGP 8.13) و`networkTimeout=600000`.
- إذا كان التنزيل بطيئاً، استخدم مرآة Maven الموجودة مسبقاً في `build.gradle`
  (Tencent/Huawei) أو حمّل التوزيعة يدوياً إلى:
  `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.13-bin\`

### `SDK location not found`
أنشئ `frontend\android\local.properties`:
```properties
sdk.dir=C\:\\Users\\<USER>\\AppData\\Local\\Android\\Sdk
```
أو شغّل `scripts\build-apk.ps1` الذي ينشئه تلقائياً.

### `JAVA_HOME is not set`
```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

### شاشة بيضاء عند الفتح
- تأكد أن `npm run build` نجح وأن `frontend\dist\index.html` موجود.
- أعد `npx cap sync android`.
- افتح `chrome://inspect` لمراقبة أخطاء WebView.

### فشل تسجيل الدخول على الجهاز
- تحقق من وصول الجهاز إلى رابط الخادم (جرّبه في المتصفح).
- على شبكة محلية استخدم IP الجهاز وليس `localhost`، واسمح للمنفذ 8000 في الجدار الناري.

## 10) توزيع التطبيق داخلياً

- أرسل ملف APK مباشرة، أو استخدم:
  - **Firebase App Distribution**
  - **Google Play — Internal testing**
  - **MDM** الخاص بالشركة
- ثبّت تحديثات بنفس مفتاح التوقيع؛ وإلا سيرفض أندرويد التحديث فوق النسخة القديمة.
