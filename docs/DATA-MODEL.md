# نموذج البيانات (مستند الحالة)

كل شيء في مستند JSON واحد. لا توجد جداول علائقية، والتحديثات تُنفَّذ على مستوى
المستند بأكمله داخل قفل/معاملة واحدة.

## 1) الجذر

```jsonc
{
  "schemaVersion": 3,
  "generatedAt": "2026-10-27T...",
  "buildings":      [],   // المباني
  "rooms":          [],   // الغرف
  "beds":           [],   // الأسرّة
  "residents":      [],   // السكان/الموظفون
  "requests":       [],   // طلبات الإسكان الداخلية
  "users":          [],   // حسابات الدخول
  "contractors":    [],   // المتعهدون
  "contractorWorkers": [],// عمال المتعهدين (سجل قديم)
  "contractorRequests": [],// طلبات إضافة/إزالة العمال
  "roles":          [],   // الأدوار والصلاحيات
  "rotations":      [],   // تنقلات الأسرّة
  "settings":       {},   // إعدادات النظام
  "permissions":    [],   // كتالوج الصلاحيات (معلوماتي)
  "notifications":  [],   // الإشعارات
  "auditLog":       [],   // سجل العمليات
  "meta":           {}    // عدّادات/معلومات محسوبة
}
```

`tree` و`user` ليسا جزءاً من المستند المخزّن: `user` يُضاف عند بناء bootstrap،
و`tree` تُحسب من المباني/الغرف/الأسرّة/السكان.

---

## 2) المباني والغرف والأسرّة

### building
```jsonc
{ "id": "…", "name": "سكن A", "location": "…", "roomIds": ["…"] }
```
- `roomIds` مرجع مشتق يُحدَّث تلقائياً عند إضافة/حذف غرفة.
- حذف مبنى يحتوي غرفاً مشغولة مرفوض (409).

### room
```jsonc
{ "id": "…", "name": "101", "buildingId": "…", "floor": 1, "bedIds": ["…"] }
```

### bed
```jsonc
{ "id": "…", "label": "A-101-1", "roomId": "…" }
```
- الإشغال **غير مخزّن** في السرير: يُستنتج من `residents` حيث `bedId` مطابق.
- `availableBeds` = عدد الأسرّة التي لا يشغلها أي ساكن.

---

## 3) الساكن (resident)

```jsonc
{
  "id": "…",
  "name": "…", "employeeCode": "…", "cardNumber": "…", "jobTitle": "…",
  "company": "…", "department": "…", "serviceType": "…",
  "shift": "…", "shiftTable": "…", "rotation": "…", "transportType": "…",
  "gender": "", "birthDate": "1995-01-01T00:00:00.000", "birthPlace": "…",
  "phone": "…",
  "status": "…",                 // حقل قديم
  "baseStatus": "متواجد",        // حقل قديم — لم يعد يؤثر في الحالة المعروضة
  "manualStatus": null,          // حقل قديم — أُلغي التجاوز اليدوي
  "leaveUntil": null,            // حقل قديم — الإجازة تُحسب من دورة الدوام
  "buildingId": null, "roomId": null, "bedId": null,  // null = غير مسكن
  "contractorId": null,          // مرتبط بمتعهد؟
  "checkInDate": null,
  "dutyCycleStart": null, "dutyWorkDays": 0, "dutyRestDays": 0,
  "departureTime": ""
}
```

### حقول محسوبة تُعاد في الاستجابات (`resident_payload`)
`attendanceStatus`, `dutyStatus`, `dutyInfo`, `buildingName`, `roomName`,
`bedLabel`, `age`, `isAssigned`, `location`.

### قواعد الحضور
- الحالة تُحسب ديناميكياً: `إجازة` في أيام الراحة، و`حاضر` في أيام العمل.
- لا يوجد تجاوز يدوي؛ `manualStatus` و`baseStatus` حقول قديمة لا تؤثر في العرض.
- من ليس لديه دورة دوام يُعد `حاضراً` إذا كان نوع خدمته يشمل «سكن».
- «غير مسكن» ليست حالة حضور، بل تعني عدم وجود سرير (`bedId = null`).

### الدوام
`dutyStatus` = `مداوم` أو `إجازة`، ويُحسب حصراً من `dutyCycleStart` + `dutyWorkDays`
+ `dutyRestDays`. إذا لم توجد دورة صحيحة يكون الحقل فارغاً.

### ثوابت مهمة
- ساكن واحد لكل سرير (لا تكرار `bedId` بين السكان).
- الساكن قد يكون له `roomId` بدون `bedId` (حالة بيانات قديمة).
- حذف الساكن يحرّر السرير ويُسجَّل في التدقيق.
- التسكين/الإخلاء يُحدّثان `buildingId`, `roomId`, `bedId` معاً.

---

## 4) المستخدم (user)

```jsonc
{
  "id": "…", "name": "…", "username": "admin",
  "password": "scrypt$…",       // أو نص قديم يُرقّى تلقائياً
  "role": "admin",              // تصنيف قديم
  "roleId": "r_admin",
  "phone": "",
  "contractorId": null, "contractorName": "", "companyName": "",
  "isActive": true,
  "mustChangePassword": false,
  "passwordVersion": 0,
  "lastLoginAt": "…"
}
```

- `roleId` هو المرجع الفعلي للصلاحيات.
- حساب المتعهد يجب أن يحمل `contractorId`.
- لا يُسمح بتعطيل/حذف آخر مدير نظام نشط.

### role
```jsonc
{ "id": "r_housing", "name": "مراقب السكن", "description": "…",
  "isSystem": true, "permissionIds": ["dashboard.view", "…"] }
```

---

## 5) المتعهد (contractor)

```jsonc
{
  "id": "…", "name": "…",
  "contractorType": "catering",   // catering | labor | cleaning | general | …
  "contactPhone": "", "contactEmail": "",
  "status": "active",
  "buildingIds": ["…"],           // المباني المسموح التسكين فيها
  "bedQuota": 84                  // السعة التعاقدية
}
```

### إحصاءات تُحسب عند الطلب (`/api/contractors`)
`workerCount`, `capacity` (= bedQuota), `freeQuota`,
`physicalBeds`, `occupiedBeds`, `freePhysicalBeds`, `occupancyPercent`,
`buildings`, `pendingRequests`, و`buildingNames`.

### عمال المتعهد
- في النسخة الحالية: العامل هو `resident` له `contractorId`.
- `contractorWorkers` قائمة قديمة تُستخدم للتوافق عند عدم وجود سكان مرتبطين.

---

## 6) طلب المتعهد (contractorRequest)

```jsonc
{
  "id": "CR-…",
  "contractorId": "…", "contractorName": "…",
  "requestType": "new_worker" | "remove_worker",
  "workerName": "…", "employeeCode": "", "jobTitle": "…",
  "workerCardNumber": "…", "workerBirthDate": "…", "workerBirthPlace": "…",
  "buildingId": null, "bedId": null, "reason": "…",
  "stage": "security" | "visitor" | "housing" | "done" | "rejected",
  "securityApprover": "", "visitorApprover": "", "housingApprover": "",
  "reviewedAt": null, "reviewNotes": "",
  "createdAt": "…"
}
```

- مراحل الإضافة: `security → visitor → housing → done`.
- مراحل الإزالة: `housing → security → visitor → done`.
- كل مرحلة تتطلب صلاحية مختلفة:
  - `security` → `requests.security`
  - `visitor` → `requests.visitor`
  - `housing` → `requests.supervise`
- `stage` النهائي `done` أو `rejected`؛ لا تعديل بعدهما.
- `request_payload` يضيف: `isAdd`, `isPending`, `typeLabel`, `stageLabel`,
  `workerAge`, `bedLabel`, `roomName`, `contractor`.

---

## 7) طلب الإسكان الداخلي (request)

```jsonc
{
  "id": "REQ-…",
  "requestType": "تسكين جديد" | "نقل سرير" | "إخلاء سكن" | "صيانة غرفة" | …,
  "residentId": null, "residentName": "…", "employeeCode": "…",
  "details": "…", "priority": "عادي",
  "status": "قيد المراجعة",
  "createdAt": "…", "createdBy": "…",
  "reviewedAt": null, "reviewNotes": "", "reviewedBy": ""
}
```

الحالات المسموحة: `قيد المراجعة`, `معتمد`, `مرفوض`, `قيد التنفيذ`, `مكتمل`.

---

## 8) التنقلات (rotation)

```jsonc
{
  "id": "ROT-…",
  "bedId": "…",
  "outgoingResidentId": "…",   // يشغل السرير حالياً
  "incomingResidentId": "…",   // الساكن الجديد
  "scheduledFor": "2026-11-01T00:00:00.000",
  "status": "مجدول" | "منفذ" | "ملغي",
  "createdAt": "…", "createdBy": "…", "executedAt": null
}
```

عند التنفيذ:
1. يُتحقق أن الساكن الحالي ما زال على السرير.
2. يُزال الساكن الحالي من السرير (بدون حذفه).
3. يُسكَّن الساكن الجديد في نفس السرير.
4. تُسجَّل العملية، وتُحدَّث حالة الطلب المرتبط.

---

## 9) الإشعارات والتدقيق

### notification
```jsonc
{
  "id": "NTF-…", "title": "…", "body": "…", "kind": "request",
  "permission": "requests.security", "userIds": [],
  "link": "/requests", "createdAt": "…",
  "actorId": "…", "actorName": "…", "readBy": ["user-id"]
}
```
- يظهر الإشعار لمن يملك `permission` أو إذا كان ضمن `userIds`.
- `readBy` يمنع التكرار لكل مستخدم.
- الحد الأقصى 3000 إشعار.

### audit entry
```jsonc
{
  "id": "AUD-…", "at": "…",
  "actorId": "…", "actorName": "…", "actorUsername": "admin",
  "action": "bed_assigned", "entity": "resident", "entityId": "…",
  "details": { "bedId": "…" }
}
```
- الحد الأقصى 8000 سجل (`AUDIT_LIMIT`).
- لا يحتوي أي أسرار.

---

## 10) الإعدادات (settings)

```jsonc
{
  "orgName": "…", "orgSubtitle": "…", "buildingLabel": "مبنى",
  "defaultPageSize": 50, "lowVacancyThreshold": 5,
  "notifyOnRequestStage": true, "notifyOnLowVacancy": true,
  "requireEmployeeCode": true, "minWorkerAge": 18,
  "features": {
    "bedRotations": true, "auditLog": true, "notifications": true,
    "bulkImport": true, "contractorPortal": true
  }
}
```

`requireEmployeeCode` و`minWorkerAge` يُطبَّقان في دورة اعتماد المتعهدين،
و`features` تُستخدم لإظهار/إخفاء أجزاء من الواجهة.

---

## 11) التوافق مع البيانات القديمة

- أسماء الحقول camelCase كما هي في `seed.json` والنسخة السابقة.
- أي حقل ناقص يُكمَّل افتراضياً عند `normalize_state` (لا تفقد البيانات).
- كلمات المرور النصية تُرقّى إلى scrypt عند الإقلاع وأول دخول.
- لا تُحذف الحقول غير المعروفة عند الحفظ — تُحفظ كما هي.
