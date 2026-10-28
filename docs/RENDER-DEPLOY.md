# النشر على Render

المشروع يضم `render.yaml` يعرّف خدمتين منفصلتين (نفس أسلوب نظام الرحلات):

| الخدمة | النوع | الجذر | الأمر |
| --- | --- | --- | --- |
| `housing-management-api` | Python | `backend` | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
| `housing-management-web` | Node | `frontend` | `node scripts/serve-static.mjs` |

## 1) قبل النشر

- المشروع مرفوع إلى مستودع GitHub/GitLab.
- حساب Render جاهز.
- رابط Supabase (Session pooler) جاهز — راجع [`SUPABASE-SETUP.md`](SUPABASE-SETUP.md).
- تأكد محلياً:

```powershell
cd backend;  .\.venv\Scripts\python.exe -m pytest -q
cd ..\frontend; npm run typecheck; npm run build
```

## 2) إنشاء الخدمات (Blueprint)

1. Render Dashboard → **New +** → **Blueprint**.
2. اختر المستودع والفرع.
3. Render يقرأ `render.yaml` ويعرض خدمتين — اضغط **Apply**.
4. انتظر انتهاء أول بناء (قد يستغرق 5–10 دقائق).

## 3) متغيرات البيئة

### خدمة API
| المتغير | القيمة |
| --- | --- |
| `ENVIRONMENT` | `production` |
| `SECRET_KEY` | يُولَّد تلقائياً (لا تستخدم قيمة ضعيفة) |
| `DATABASE_URL` | رابط Supabase Session pooler (**إلزامي**) |
| `STATE_KEY` | `housing_state_v1` (**لا تغيّره**) |
| `CORS_ORIGINS` | `*` مبدئياً، أو رابط الواجهة تحديداً |
| `FORCE_PASSWORD_CHANGE` | `false` (اجعلها `true` بعد تدريب المستخدمين) |
| `MAX_UPLOAD_MB` | `25` |
| `AUDIT_LIMIT` | `8000` |

### خدمة الويب
| المتغير | القيمة |
| --- | --- |
| `NEXT_PUBLIC_API_URL` | رابط خدمة API، مثال `https://housing-management-api.onrender.com` |
| `NODE_VERSION` | `24.21.0` |
| `NEXT_TELEMETRY_DISABLED` | `1` |

> `NEXT_PUBLIC_API_URL` يُدمج في ملفات الواجهة **وقت البناء**. بعد تغييره أعد نشر
> خدمة الويب (Manual Deploy → Clear build cache & deploy).

## 4) التحقق بعد النشر

1. فحص صحة الـ API:

```powershell
curl.exe https://housing-management-api.onrender.com/health
```

يجب أن يعيد `"ok": true` و`"store": "postgres"` وأعداد السكان الصحيحة.

2. افتح رابط الواجهة، وسجّل الدخول بحساب حقيقي.
3. تحقق من:
   - ظهور لوحة المعلومات بالأرقام الصحيحة.
   - فتح شاشة السكان وعدّ السجلات.
   - إنشاء طلب متعهد تجريبي ثم حذفه (أو رفضه) للتحقق من الكتابة.
   - شاشة **إدارة النظام → تشخيص** (يجب أن تظهر `postgres` وبلا أخطاء أمان).

## 5) CORS

- عند استخدام خدمتين على نطاقين مختلفين، يجب أن يسمح الـ API بأصل الواجهة.
- الأسهل: `CORS_ORIGINS=*` (مقبول لأن الخادم لا يستخدم Cookies).
- الأفضل لاحقاً: `CORS_ORIGINS=https://YOUR-WEB.onrender.com`.

## 6) الخطة المجانية وسلوك الإقلاع البارد

- خدمة Render المجانية تنام بعد فترة خمول؛ أول طلب قد يستغرق 30–60 ثانية.
- الواجهة تتعامل مع ذلك: تسجيل الدخول يعيد المحاولة تلقائياً مرة واحدة.
- شاشة الدخول تعرض «جارٍ الدخول...» أثناء الإقلاع.
- للتطبيقات الحساسة للتأخير: ترقية الخطة أو استخدام Cron خارجي لتنشيط الخدمة.

## 7) التحديث والتراجع

- **Auto Deploy** مفعّل: كل دفع إلى الفرع يعيد النشر.
- للتراجع: Render → الخدمة → **Deploys** → اختر نشراً سابقاً → **Redeploy**.
- قبل كل تحديث كبير: نزّل نسخة احتياطية من شاشة الإدارة.

## 8) المراقبة والسجلات

- **Logs** لكل خدمة (تظهر أخطاء الإقلاع ورسائل الأمان).
- إذا فشل الإقلاع بسبب `SECRET_KEY`:
  ```
  RuntimeError: إعدادات أمان غير صالحة: SECRET_KEY إلزامي وقوي...
  ```
  أضف/أعد توليد `SECRET_KEY` بطول 32+ حرفاً.
- إذا فشل الاتصال بقاعدة البيانات، تحقق من:
  - صحة الرابط و`sslmode=require`.
  - أن الخادم يستخدم Session pooler (IPv4).
  - عدم انتهاء صلاحية كلمة المرور.

## 9) أسماء نطاقات مقترحة

- API: `housing-api.yourdomain.com`
- Web: `housing.yourdomain.com`

أضف النطاق من **Settings → Custom Domains**، ثم:
- حدّث `NEXT_PUBLIC_API_URL` إن تغيّر رابط الـ API.
- أضف نطاق الواجهة إلى `CORS_ORIGINS`.

## 10) نشر خدمة واحدة (بديل)

إذا أردت خدمة واحدة فقط:
1. ابنِ الواجهة داخل أمر بناء الخادم (يتطلب Node في بيئة Python، غير مضمون على Render).
2. أو استخدم Dockerfile يجمع Python + Node.

الطريقة الموصى بها والمُختبرة تبقى **خدمتان** كما في `render.yaml`.
