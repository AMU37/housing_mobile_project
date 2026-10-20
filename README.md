# تطبيق إدارة الشؤون — إدارة السكن (Android / Flutter + خادم مشترك)

تطبيق Flutter عربي RTL لإدارة سكن العاملين، يعمل الآن عبر **خادم مشترك** بحيث تصل طلبات المتعهدين/المقاولين إلى مراقب السكن ومشرف الأمن مهما كانت أجهزتهم وشبكاتهم.

## البنية

```
جوال المتعهد ─┐
جوال المراقب ─┼─► خادم مشترك (Render) ─► قاعدة بيانات دائمة (Supabase/Postgres)
جوال الأمن   ─┘
```

- **التطبيق** (`lib/`): واجهة Flutter للجوال والويب.
- **الخادم** (`server/`): Node.js بدون أطر ثقيلة، يدعم تخزين Postgres أو ملف محلي.
- الطلبات تُنشأ من المتعهد، تُعتمد من مراقب السكن، ثم تُنفّذ من مشرف الأمن.

## تشغيل الخادم محلياً

```powershell
cd server
npm install
node server.js
```

- بدون `DATABASE_URL` → يُخزّن في `server/data.json` (للتطوير فقط).
- مع `DATABASE_URL` → تخزين دائم في PostgreSQL.

نقطة الفحص: `http://127.0.0.1:8080/api/health`

## النشر على Render + Supabase (للإنتاج)

### 1) إنشاء قاعدة بيانات Supabase
1. أنشئ مشروعاً في supabase.com.
2. من **Connect → Session pooler** انسخ سلسلة الاتصال، مثال:
   `postgresql://postgres.<ref>:<password>@<pooler-host>:5432/postgres?sslmode=require`

### 2) النشر على Render
1. ارفع هذا المستودع إلى GitHub.
2. في Render: **New → Blueprint** واختر المستودع (سيقرأ `render.yaml`).
3. عيّن متغير البيئة `DATABASE_URL` بسلسلة Supabase أعلاه.
4. بعد النشر، سيكون عنوان الخادم مثل `https://housing-server.onrender.com/api`.

### 3) بناء التطبيق على عنوان الخادم المنشور

```powershell
flutter build apk --release --dart-define=HOUSING_API_BASE_URL=https://housing-server.onrender.com/api
flutter build web --release --dart-define=HOUSING_API_BASE_URL=https://housing-server.onrender.com/api
```

> يمكن دائماً تغيير العنوان داخل التطبيق من شاشة الدخول → إعداد الخادم (يُحفظ على الجهاز).

## الحسابات التجريبية

| المستخدم | الدور |
|---|---|
| `ctr01` | متعهد (المطعم) |
| `ctr02` / `ctr04` / `contractor` | متعهدون |
| `supervisor` | مراقب السكن |
| `security` | مشرف الأمن |
| `admin` | مدير النظام |

كلمة المرور لكل الحسابات: `123456`.

## واجهات الخادم

| المسار | الغرض |
|---|---|
| `GET /api/health` | فحص صحة الخدمة |
| `POST /api/auth/login` | تسجيل الدخول (يعيد token) |
| `GET /api/bootstrap` | كل البيانات عند بدء الجلسة |
| `GET /api/contractor-requests` | طلبات المتعهدين |
| `POST /api/contractor-requests` | إنشاء طلب |
| `POST /api/contractor-requests/{id}/approve-housing` | اعتماد مراقب السكن |
| `POST /api/contractor-requests/{id}/approve-security` | اعتماد/تنفيذ مشرف الأمن |
| `POST /api/contractor-requests/{id}/reject` | رفض الطلب |

## بنية المشروع

```text
housing_mobile_project/
├── lib/                # تطبيق Flutter
├── server/             # خادم Node.js المشترك
│   ├── server.js
│   ├── db.js           # طبقة التخزين (Postgres/ملف)
│   ├── seed.json       # بيانات البذور الأولى
│   └── package.json
├── tool/export_seed.dart   # توليد seed.json من البيانات التجريبية
├── render.yaml
└── pubspec.yaml
```

© تطبيق إدارة الشؤون لأتمتة العمليات — وحدة إدارة السكن.
