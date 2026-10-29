# نظام إدارة السكن — الخادم الخلفي

هذا المستودع مخصص لخادم **FastAPI** فقط. لا يحتوي على واجهة Next.js.

## نشره على Render

يمكن إنشاء Web Service أو Blueprint من هذا المستودع، على الفرع `main`.

إعدادات Web Service اليدوية:
- Runtime: Python
- Root Directory: اتركه فارغًا
- Build Command: `pip install -r requirements.txt`
- Start Command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- Health Check Path: `/health`

يتضمن المستودع `render.yaml` لخدمة واحدة باسم `housing-system-api`.

## متغيرات البيئة المطلوبة

اضبطها من إعدادات Render، ولا تحفظ الأسرار داخل GitHub:

- `ENVIRONMENT=production`
- `SECRET_KEY`: مفتاح عشوائي طويل وفريد. استخدم Generate في Render.
- `DATABASE_URL`: رابط PostgreSQL/Supabase الإنتاجي الصحيح.
- `STATE_KEY=housing_state_v1`: احتفظ بهذا المفتاح لقراءة مستند الحالة الحالي من جدول `kv_store`.
- `CORS_ORIGINS`: قائمة أصل الواجهة التي ستتصل بالخادم، مفصولة بفواصل. يمكن ضبطها بعد معرفة عنوان الواجهة.

**حماية بيانات الإنتاج:** لا تستبدل قاعدة البيانات الحالية بقاعدة جديدة، ولا تغيّر `STATE_KEY`. بعد النشر، تحقق من أن `/health` يعرض `store: postgres` وأعداد السجلات المتوقعة قبل إجراء أي تعديل على البيانات.

## تشغيل محلي

من جذر المستودع:

```powershell
python -m venv .venv
.venv\\Scripts\\python -m pip install -r requirements.txt
.venv\\Scripts\\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

في وضع التطوير المحلي، إذا لم يتم ضبط `DATABASE_URL`، يستخدم النظام ملف JSON محليًا. لا تستخدم هذا الوضع كقاعدة بيانات إنتاجية على Render.
