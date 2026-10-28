# إعداد Supabase (قاعدة بيانات الإنتاج)

النظام لا يحتاج جداول علائقية: كل البيانات في مستند JSON واحد داخل جدول
`kv_store`. هذا يحافظ على بيانات النسخة الحالية بالكامل.

## 1) إنشاء المشروع

1. ادخل إلى <https://supabase.com> وأنشئ مشروعاً جديداً (أو استخدم المشروع الحالي).
2. احفظ **كلمة مرور قاعدة البيانات** في مكان آمن.
3. من **Project Settings → Database** انسخ رابط الاتصال.

## 2) اختيار رابط الاتصال

استخدم **Session pooler** (وليس Direct connection) لأنه يعمل مع IPv4 على Render:

```text
postgresql://postgres.<PROJECT_REF>:<PASSWORD>@aws-0-<REGION>.pooler.supabase.com:5432/postgres?sslmode=require
```

- إذا احتوى الرابط على `postgres://` يمكن تركه كما هو — الخادم يحوّله تلقائياً.
- لا تحذف `sslmode=require`.
- إن احتوت كلمة المرور على رموز خاصة (`@`, `#`, `%`) يجب ترميزها URL-encoded.

ضع الرابط في `backend\.env`:

```dotenv
DATABASE_URL=postgresql://postgres.xxxx:XXXXXXXX@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require
STATE_KEY=housing_state_v1
```

> **لا تغيّر `STATE_KEY`.** بيانات الإنتاج محفوظة تحت `housing_state_v1`.

## 3) التحقق من الجدول

عند أول تشغيل، ينشئ الخادم الجدول تلقائياً إن لم يكن موجوداً:

```sql
CREATE TABLE IF NOT EXISTS kv_store (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

للتحقق من وجود بياناتك (Supabase → SQL Editor):

```sql
-- هل المستند موجود؟
SELECT key, updated_at, pg_column_size(value) AS bytes
FROM kv_store
WHERE key = 'housing_state_v1';

-- أعداد سريعة من داخل المستند
SELECT
  jsonb_array_length(value->'buildings')  AS buildings,
  jsonb_array_length(value->'rooms')      AS rooms,
  jsonb_array_length(value->'beds')       AS beds,
  jsonb_array_length(value->'residents')  AS residents,
  jsonb_array_length(value->'users')      AS users
FROM kv_store
WHERE key = 'housing_state_v1';
```

الأعداد المتوقّعة للبذرة الحالية: 10 مبانٍ، 133 غرفة، 681 سريراً، 1,363 ساكناً،
30 مستخدماً، 217 طلب متعهد.

## 4) النسخ الاحتياطي

### من Supabase
- **Database → Backups** (حسب خطة المشروع).
- أو تصدير المستند يدوياً:

```sql
SELECT value FROM kv_store WHERE key = 'housing_state_v1';
```

### من التطبيق
شاشة **إدارة النظام → نسخ احتياطي** تنزّل ملف JSON كامل، ويمكن استعادته من نفس
الشاشة (يتطلب صلاحية `admin.backup`).

قبل أي ترقية كبيرة:
1. نزّل نسخة JSON من التطبيق.
2. احتفظ بنسخة SQL/Supabase إن أمكن.
3. نفّذ الترقية وتحقق من الأعداد أعلاه.

## 5) الأمان في Supabase

- لا تضع `DATABASE_URL` في الواجهة أو في مستودع Git — فقط في `.env`
  أو متغيرات Render.
- استخدام اتصال مباشر بـ Postgres يعني أن RLS لا يؤثر (يتجاوزها دور
  `postgres`). صلاحيات المستخدمين تُدار داخل التطبيق نفسه (JWT + Permissions).
- قيّد الوصول إلى مشروع Supabase على فريق العمل فقط، وفعّل المصادقة الثنائية.
- بدّل كلمة مرور القاعدة إذا تسرّبت، ثم حدّث `DATABASE_URL` في Render.

## 6) الأسئلة الشائعة

**هل أفقد البيانات الحالية عند تشغيل النظام الجديد؟**
لا، ما دام `DATABASE_URL` و`STATE_KEY` صحيحين؛ الخادم يقرأ نفس المستند ويكتب فيه.

**هل يحتاج النظام ترحيل جداول؟**
لا. لا توجد جداول سكان/مبانٍ منفصلة في هذه النسخة.

**ماذا يحدث إذا كان الجدول فارغاً؟**
سيتم تحميل البذرة `seed.json` وكتابتها مرة واحدة. لا تفعل ذلك على قاعدة الإنتاج
إلا إذا كنت تريد فعلاً إعادة التعيين.

**هل يمكن استخدام قاعدة Postgres عادية (Render/Neon)؟**
نعم، أي PostgreSQL 13+ يعمل. الجدول يُنشأ تلقائياً.
