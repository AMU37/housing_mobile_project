# أمثلة استدعاء API

الأساس المحلي: `http://127.0.0.1:8000`
الإنتاج: رابط خدمة API على Render.

> جميع المسارات المحمية تحتاج الترويسة:
> `Authorization: Bearer <ACCESS_TOKEN>`
> والاستجابات بصيغة JSON إلا التصدير (CSV).

## PowerShell — جلسة عمل

```powershell
$base = "http://127.0.0.1:8000"
$body = @{ username = "admin"; password = "123456" } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri "$base/api/auth/login" `
    -ContentType "application/json; charset=utf-8" `
    -Body ([Text.Encoding]::UTF8.GetBytes($body))

$tok = $login.access_token
$H = @{ Authorization = "Bearer $tok" }

$login.user | Select-Object username, roleName, mustChangePassword
$login.user.permissions
```

## المصادقة

| الطلب | المسار |
| --- | --- |
| تسجيل الدخول | `POST /api/auth/login` |
| تجديد التوكن | `POST /api/auth/refresh` |
| بيانات المستخدم الحالي | `GET /api/auth/me` |
| تغيير كلمة المرور | `POST /api/auth/change-password` |
| تسجيل الخروج | `POST /api/auth/logout` |

```powershell
# تجديد
Invoke-RestMethod -Method Post -Uri "$base/api/auth/refresh" `
  -ContentType "application/json" `
  -Body (@{ refresh_token = $login.refresh_token } | ConvertTo-Json)

# تغيير كلمة المرور
Invoke-RestMethod -Method Post -Uri "$base/api/auth/change-password" -Headers $H `
  -ContentType "application/json" `
  -Body (@{ current_password = "123456"; new_password = "NewPass@2026" } | ConvertTo-Json)
```

## bootstrap (تحميل كل البيانات)

```powershell
$b = Invoke-RestMethod -Uri "$base/api/bootstrap" -Headers $H
$b.PSObject.Properties.Name
$b.meta.counts
```

القوائم العلوية: `buildings, rooms, beds, residents, requests, users, contractors,
contractorWorkers, contractorRequests, roles, rotations, settings, permissions,
notifications` — إضافة إلى `tree` (شجرة السكن) و`auditLog` حسب الصلاحيات.

## السكان

```powershell
# بحث وتصفية
Invoke-RestMethod -Uri "$base/api/residents?q=احمد&page=1&pageSize=20&housingOnly=true" -Headers $H

# إضافة ساكن
$new = @{
  name = "محمد علي أحمد"; employeeCode = "70001"; jobTitle = "فني"
  company = "شركة الصيانة"; department = "التشغيل"; serviceType = "داخلي"
  phone = "0500000000"; baseStatus = "غير مسكن"
} | ConvertTo-Json
$resident = Invoke-RestMethod -Method Post -Uri "$base/api/residents" -Headers $H `
  -ContentType "application/json" -Body ([Text.Encoding]::UTF8.GetBytes($new))
$resident.id

# تسكين على سرير
Invoke-RestMethod -Method Post -Uri "$base/api/residents/$($resident.id)/assign-bed" -Headers $H `
  -ContentType "application/json" -Body (@{ bedId = "<BED_ID>" } | ConvertTo-Json)

# إخلاء
Invoke-RestMethod -Method Post -Uri "$base/api/residents/$($resident.id)/unassign-bed" -Headers $H

# الحضور يُحسب تلقائياً من دورة الدوام (لا يوجد تعديل يدوي)
# حاضر في أيام العمل، وإجازة في أيام الراحة.

# تصدير CSV
Invoke-WebRequest -Uri "$base/api/residents/export.csv" -Headers $H -OutFile "residents.csv"
```

قيم الحضور المحسوبة: `حاضر` أو `إجازة` فقط.

## السكن والأسرّة والتنقلات

```powershell
# الشجرة الكاملة
$tree = Invoke-RestMethod -Uri "$base/api/housing/tree" -Headers $H

# المباني / الغرف / الأسرّة
$buildings = Invoke-RestMethod -Uri "$base/api/housing/buildings" -Headers $H
$rooms     = Invoke-RestMethod -Uri "$base/api/housing/rooms?buildingId=$($buildings.items[0].id)" -Headers $H
$beds      = Invoke-RestMethod -Uri "$base/api/housing/beds?roomId=$($rooms.items[0].id)" -Headers $H

# إضافة مبنى
Invoke-RestMethod -Method Post -Uri "$base/api/housing/buildings" -Headers $H `
  -ContentType "application/json" -Body (@{ name = "سكن C"; code = "C"; floors = 3 } | ConvertTo-Json)

# جدولة تنقل بين ساكنين على سرير ثم تنفيذها
$rotation = Invoke-RestMethod -Method Post -Uri "$base/api/housing/rotations" -Headers $H `
  -ContentType "application/json" -Body (@{
      bedId = "<BED_ID>"
      outgoingResidentId = "<CURRENT_RESIDENT_ID>"
      incomingResidentId = "<NEXT_RESIDENT_ID>"
      scheduledFor = "2026-11-01"
  } | ConvertTo-Json)
Invoke-RestMethod -Method Post -Uri "$base/api/housing/rotations/$($rotation.id)/execute" -Headers $H
```

## طلبات الإسكان (الداخلية)

```powershell
$req = @{
  requestType = "تسكين جديد"; residentName = "محمد علي"; employeeCode = "70001"
  details = "طلب تسكين قريب من موقع العمل"; priority = "عادي"
} | ConvertTo-Json
$created = Invoke-RestMethod -Method Post -Uri "$base/api/requests" -Headers $H `
  -ContentType "application/json" -Body ([Text.Encoding]::UTF8.GetBytes($req))

# تغيير الحالة (يتطلب requests.supervise أو ما يعادلها)
Invoke-RestMethod -Method Patch -Uri "$base/api/requests/$($created.id)/status" -Headers $H `
  -ContentType "application/json" -Body (@{ status = "معتمد"; notes = "تمت الموافقة" } | ConvertTo-Json)
```

الحالات: `قيد المراجعة` → `معتمد` → `قيد التنفيذ` → `مكتمل`، مع `مرفوض`.

## طلبات المتعهدين (سلسلة الاعتماد)

```powershell
# طلب إضافة عامل جديد (يبدأ عند الأمن)
$cr = @{
  contractorId = "<CONTRACTOR_ID>"; requestType = "new_worker"
  workerName = "عامل جديد"; workerCardNumber = "1234567890"
  workerBirthDate = "1995-05-01"; workerBirthPlace = "القاهرة"
  jobTitle = "عامل نظافة"; reason = "احتياج تشغيلي"
} | ConvertTo-Json
$r = Invoke-RestMethod -Method Post -Uri "$base/api/contractor-requests" -Headers $H `
  -ContentType "application/json" -Body ([Text.Encoding]::UTF8.GetBytes($cr))

# مراجعة الطلبات المعلّقة
Invoke-RestMethod -Uri "$base/api/contractor-requests?stage=pending" -Headers $H
Invoke-RestMethod -Uri "$base/api/contractor-requests/pending-counts" -Headers $H

# اعتماد المرحلة الأمنية (بحساب security)
Invoke-RestMethod -Method Post -Uri "$base/api/contractor-requests/$($r.id)/approve?stage=security" -Headers $H `
  -ContentType "application/json" -Body (@{ notes = "تم التحقق" } | ConvertTo-Json)

# اعتماد مراقب الزوار — كود الموظف إلزامي لطلبات الإضافة
Invoke-RestMethod -Method Post -Uri "$base/api/contractor-requests/$($r.id)/approve?stage=visitor" -Headers $H `
  -ContentType "application/json" -Body (@{ employeeCode = "70002"; notes = "مطابق" } | ConvertTo-Json)

# اعتماد السكن — ينفّذ التسكين
Invoke-RestMethod -Method Post -Uri "$base/api/contractor-requests/$($r.id)/approve?stage=housing" -Headers $H `
  -ContentType "application/json" -Body (@{ notes = "تم التسكين" } | ConvertTo-Json)

# رفض
Invoke-RestMethod -Method Post -Uri "$base/api/contractor-requests/$($r.id)/reject" -Headers $H `
  -ContentType "application/json" -Body (@{ notes = "بيانات ناقصة" } | ConvertTo-Json)
```

## المتعهدون

```powershell
Invoke-RestMethod -Uri "$base/api/contractors?page=1&pageSize=50" -Headers $H
Invoke-RestMethod -Uri "$base/api/contractors/<ID>" -Headers $H
Invoke-RestMethod -Uri "$base/api/contractors/<ID>/stats" -Headers $H
Invoke-RestMethod -Uri "$base/api/contractors/<ID>/workers" -Headers $H
Invoke-RestMethod -Uri "$base/api/contractors/<ID>/portal" -Headers $H
```

## التقارير والتصدير

```powershell
Invoke-RestMethod -Uri "$base/api/reports/dashboard" -Headers $H
Invoke-RestMethod -Uri "$base/api/reports/occupancy" -Headers $H
Invoke-RestMethod -Uri "$base/api/reports/attendance?groupBy=company" -Headers $H
Invoke-RestMethod -Uri "$base/api/reports/contractors" -Headers $H
Invoke-RestMethod -Uri "$base/api/reports/requests" -Headers $H
Invoke-RestMethod -Uri "$base/api/reports/duty?date=2026-10-27" -Headers $H

# CSV: employees | buildings | contractors | requests | duty
Invoke-WebRequest -Uri "$base/api/reports/export?kind=employees" -Headers $H -OutFile "employees.csv"
```

## الإدارة

```powershell
# المستخدمون والأدوار والصلاحيات
Invoke-RestMethod -Uri "$base/api/admin/users" -Headers $H
Invoke-RestMethod -Uri "$base/api/admin/roles" -Headers $H
Invoke-RestMethod -Uri "$base/api/admin/permissions" -Headers $H

# سجل العمليات
Invoke-RestMethod -Uri "$base/api/admin/audit?limit=100" -Headers $H

# نسخة احتياطية (JSON) أو تنزيل ملف
Invoke-RestMethod -Uri "$base/api/admin/backup" -Headers $H
Invoke-WebRequest  -Uri "$base/api/admin/backup?download=true" -Headers $H -OutFile "backup.json"

# استعادة (تأكيد إلزامي بكلمة RESTORE)
$backup = Get-Content "backup.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$restore = @{ confirm = "RESTORE"; data = $backup.data } | ConvertTo-Json -Depth 100
Invoke-RestMethod -Method Post -Uri "$base/api/admin/restore" -Headers $H `
  -ContentType "application/json" -Body ([Text.Encoding]::UTF8.GetBytes($restore))

# تشخيص
Invoke-RestMethod -Uri "$base/api/admin/diagnostics" -Headers $H
```

## البحث الشامل والصحة

```powershell
Invoke-RestMethod -Uri "$base/api/search?q=احمد" -Headers $H
curl.exe $base/api/health
```

## رموز الأخطاء

| الرمز | المعنى |
| --- | --- |
| `400` | بيانات غير صالحة أو حالة غير مسموحة |
| `401` | انتهت الجلسة أو بيانات دخول خاطئة |
| `403` | لا تملك الصلاحية المطلوبة |
| `404` | العنصر غير موجود |
| `409` | تعارض (سرير مشغول، تكرار بطاقة، طلب قيد الاعتماد) |
| `422` | فشل تحقق الحقول (تظهر رسالة عربية بالحقل) |
| `429` | محاولات كثيرة — انتظر قليلاً |
