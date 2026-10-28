# التثبيت والتشغيل على Windows

## 1) المتطلبات

| البرنامج | الإصدار الموصى به | التحقق |
| --- | --- | --- |
| Python | 3.13 | `py -3.13 --version` |
| Node.js | 24.x | `node --version` |
| npm | 10+ | `npm --version` |
| Git (اختياري) | أحدث إصدار | `git --version` |
| Android Studio (لـ APK) | أحدث إصدار مع SDK 36 | — |

> إذا لم يكن Python مثبتاً: ثبّته من <https://www.python.org/downloads/> مع خيار
> **Add python.exe to PATH**.

## 2) الإعداد التلقائي

```powershell
cd D:\ali\housing_mobile_android_project\housing-management-system
.\scripts\setup.ps1
```

يقوم السكربت بـ:
1. إنشاء `backend\.env` من `.env.example` إن لم يكن موجوداً.
2. إنشاء بيئة `backend\.venv` وتثبيت `requirements.txt`.
3. تثبيت حزم الواجهة إن لم تكن `frontend\node_modules` موجودة.

إذا ظهرت رسالة منع تنفيذ السكربتات:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 3) تشغيل النظام

```powershell
.\scripts\start-local.ps1
```

- الخادم الخلفي: <http://127.0.0.1:8000>
- الواجهة: <http://localhost:3000>
- مستندات API (تطوير فقط): <http://127.0.0.1:8000/docs>

سجّل الدخول بـ `admin` / `123456`.

### التشغيل اليدوي

```powershell
# نافذة 1 — الخادم
cd backend
Copy-Item .env.example .env -ErrorAction SilentlyContinue
py -3.13 -m venv .venv                      # مرة واحدة
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8000

# نافذة 2 — الواجهة
cd frontend
npm install                                  # مرة واحدة
npm run dev
```

## 4) ملفات البيانات

| الملف | الغرض |
| --- | --- |
| `backend\seed.json` | البذرة الكاملة (لا تُعدَّل إلا بقرار مقصود) |
| `backend\data.json` | حالة التشغيل المحلية، تُنشأ من البذرة عند أول تشغيل |

لإعادة التعيين إلى البذرة:

```powershell
Remove-Item backend\data.json
# أعد تشغيل الخادم — سيُعاد إنشاؤه تلقائياً
```

> **تحذير:** حذف `data.json` يمحو أي تعديلات محلية غير محفوظة في نسخة احتياطية.

## 5) أوامر يومية

```powershell
# فحص الأنواع
cd frontend; npm run typecheck

# بناء الواجهة
cd frontend; npm run build

# تقديم النسخة المبنية محلياً على 3444
.\scripts\serve-local.ps1

# الاختبارات
cd backend; .\.venv\Scripts\python.exe -m pytest -q
```

## 6) حل المشكلات الشائعة

### «تعذر الاتصال بالخادم» في الواجهة
- تأكد أن الخادم يعمل على المنفذ 8000: `curl http://127.0.0.1:8000/health`
- الواجهة على منفذ 3000 مضبوطة في CORS افتراضياً. إذا شغّلت الواجهة على منفذ آخر
  أضفه إلى `CORS_ORIGINS` في `backend\.env`، مثال:
  `CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3444`

### المنفذ مستخدم
```powershell
Get-NetTCPConnection -LocalPort 8000 -State Listen | Select-Object OwningProcess
Stop-Process -Id <رقم-العملية> -Force
```

### النص العربي يظهر مشوّهاً في الطرفية
هذه مشكلة عرض في PowerShell وليست في البيانات. افتح الملفات بمحرر يدعم UTF-8،
أو استخدم `Get-Content file.json -Encoding UTF8`.

### `pip install` فشل بسبب الشبكة
أعد المحاولة، أو استخدم مرآة:
```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### الخطأ `SECRET_KEY ضعيف` في الإنتاج
هذا سلوك مقصود. استخدم مفتاحاً عشوائياً بطول 32 حرفاً على الأقل (Render يوفّر
خيار **Generate**).

## 7) تشغيل الخادم منفرداً (خدمة واحدة)

الخادم يستطيع تقديم الواجهة المبنية تلقائياً من `frontend\dist`:

```powershell
cd frontend; npm run build
cd ..\backend; .\.venv\Scripts\python.exe -m uvicorn app.main:app --port 8000
```

ثم افتح <http://127.0.0.1:8000> — الواجهة والـ API على نفس الأصل (لا حاجة إلى CORS).
