/**
 * خادم إدارة السكن — بدون أي تبعيات خارجية (Node 18+).
 *
 * التشغيل:
 *   node server.js            (المنفذ الافتراضي 8080)
 *   PORT=9000 node server.js
 *
 * البيانات تُحفظ في data.json بجانب الخادم، وتُبذر أول مرة من seed.json
 * (ينشئه: dart run tool/export_seed.dart).
 */
'use strict';

const http = require('http');
const path = require('path');
const crypto = require('crypto');
const { createStore } = require('./db');

const PORT = Number(process.env.PORT || 8080);

// ---------------------------------------------------------------------------
// التخزين (سنُهيّأ قبل الاستماع؛ يدعم Postgres أو ملفاً محلياً)
// ---------------------------------------------------------------------------

let store = null;
let db = null;

async function saveDb(next) {
  if (next) db = next;
  await store.save(db);
}

// ---------------------------------------------------------------------------
// المصادقة والصلاحيات
// ---------------------------------------------------------------------------

function rolePermissions(user) {
  const roleId = user.roleId && user.roleId.length ? user.roleId : defaultRoleId(user);
  const role = db.roles.find((r) => r.id === roleId);
  return role ? new Set(role.permissionIds) : new Set();
}

function defaultRoleId(user) {
  switch (user.role) {
    case 'admin':
      return 'r_admin';
    case 'contractor':
      return 'r_contractor';
    case 'securitySupervisor':
      return 'r_security';
    case 'visitorSupervisor':
      return 'r_visitor';
    default:
      return 'r_housing';
  }
}

function publicUser(user) {
  const { password, ...rest } = user;
  return rest;
}

function userByToken(req) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token || !db.tokens[token]) return null;
  const user = db.users.find((u) => u.id === db.tokens[token]);
  return user || null;
}

// ---------------------------------------------------------------------------
// منطق العمليات (مطابق لمنطق التطبيق)
// ---------------------------------------------------------------------------

function contractorById(id) {
  return db.contractors.find((c) => c.id === id) || null;
}

function workersFor(contractorId) {
  return db.residents.filter((r) => r.contractorId === contractorId);
}

function freeBedCount(contractorId) {
  const c = contractorById(contractorId);
  if (!c) return 0;
  const free = (c.bedQuota || 0) - workersFor(contractorId).length;
  return free > 0 ? free : 0;
}

function freeBedsFor(contractorId) {
  const c = contractorById(contractorId);
  if (!c) return [];
  const roomIds = db.rooms.filter((r) => c.buildingIds.includes(r.buildingId)).map((r) => r.id);
  const used = new Set(db.residents.filter((r) => r.bedId).map((r) => r.bedId));
  return db.beds.filter((b) => roomIds.includes(b.roomId) && !used.has(b.id));
}

function createResident(req) {
  const bed = freeBedsFor(req.contractorId)[0];
  if (!bed) return { error: 'لا يوجد فراغ متاح للتنفيذ' };
  const room = db.rooms.find((r) => r.id === bed.roomId);
  return {
    resident: {
      id: 'u' + Date.now() + Math.floor(Math.random() * 1000),
      employeeCode: req.employeeCode || '',
      name: req.workerName,
      jobTitle: req.jobTitle && req.jobTitle.length ? req.jobTitle : 'عامل متعهد',
      company: req.contractorName,
      department: 'متعهدون ومقاولون',
      shift: 'نهاري',
      rotation: '',
      serviceType: '',
      baseStatus: 'متواجد',
      manualStatus: null,
      buildingId: room ? room.buildingId : null,
      roomId: room ? room.id : null,
      bedId: bed.id,
      checkInDate: new Date().toISOString(),
      leaveUntil: null,
      phone: '',
      shiftTable: '',
      dutyCycleStart: null,
      dutyWorkDays: 0,
      dutyRestDays: 0,
      contractorId: req.contractorId,
      gender: '',
      transportType: '',
      departureTime: '',
      cardNumber: req.workerCardNumber || '',
      birthDate: req.workerBirthDate || null,
      birthPlace: req.workerBirthPlace || '',
    },
    bedId: bed.id,
  };
}

function validateNewWorker(body) {
  if (!body.contractorId || !contractorById(body.contractorId)) return 'المتعهد غير موجود';
  if (!body.workerName || !String(body.workerName).trim()) return 'يرجى إدخال اسم العامل';
  if (!body.workerCardNumber || !String(body.workerCardNumber).trim()) return 'يرجى إدخال رقم البطاقة';
  if (!body.workerBirthDate) return 'يرجى تحديد تاريخ الميلاد';
  if (!body.workerBirthPlace || !String(body.workerBirthPlace).trim()) return 'يرجى إدخال مكان الميلاد';
  const bd = new Date(body.workerBirthDate);
  if (isNaN(bd.getTime())) return 'تاريخ الميلاد غير صحيح';
  const now = new Date();
  let age = now.getFullYear() - bd.getFullYear();
  if (now.getMonth() < bd.getMonth() || (now.getMonth() === bd.getMonth() && now.getDate() < bd.getDate())) {
    age--;
  }
  if (age < 18) return 'لا يسمح بإضافة موظف أقل من 18 عاماً';
  if (freeBedCount(body.contractorId) <= 0) {
    const c = contractorById(body.contractorId);
    return 'لا يوجد سرير متاح لدى المتعهد (' + (c ? c.name : '') + ')';
  }
  return null;
}

function validateRemoveWorker(body) {
  if (!body.contractorId || !contractorById(body.contractorId)) return 'المتعهد غير موجود';
  if (!body.workerName || !String(body.workerName).trim()) return 'يرجى إدخال اسم العامل';
  const exists = workersFor(body.contractorId).some(
    (r) =>
      r.name === String(body.workerName).trim() ||
      (body.employeeCode && r.employeeCode === body.employeeCode)
  );
  if (!exists) return 'العامل غير موجود ضمن عمالة المتعهد';
  return null;
}

// ---------------------------------------------------------------------------
// خادم HTTP
// ---------------------------------------------------------------------------

function sendJson(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
  });
  res.end(body);
}

function sendError(res, status, message) {
  sendJson(res, status, { error: message });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (c) => {
      raw += c;
      if (raw.length > 1e6) reject(new Error('too large'));
    });
    req.on('end', () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

function requireAuth(req, res) {
  const user = userByToken(req);
  if (!user) {
    sendError(res, 401, 'غير مصادق — سجّل الدخول أولاً');
    return null;
  }
  return user;
}

function requirePermission(req, res, perm) {
  const user = requireAuth(req, res);
  if (!user) return null;
  if (!rolePermissions(user).has(perm)) {
    sendError(res, 403, 'لا تملك صلاحية هذا الإجراء');
    return null;
  }
  return user;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const route = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method;

  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
    });
    return res.end();
  }

  try {
    // ---- صحة الخدمة (لا يحتاج مصادقة) ----
    if (method === 'GET' && (route === '/api/health' || route === '/health')) {
      return sendJson(res, 200, { ok: true, time: new Date().toISOString() });
    }

    // ---- تسجيل الدخول ----
    if (method === 'POST' && (route === '/api/auth/login' || route === '/auth/login')) {
      const body = await readBody(req);
      const username = String(body.username || '').trim().toLowerCase();
      const password = String(body.password || '');
      const user = db.users.find(
        (u) => u.username.toLowerCase() === username && u.password === password
      );
      if (!user) return sendError(res, 401, 'اسم المستخدم أو كلمة المرور غير صحيحة');
      const token = crypto.randomBytes(24).toString('hex');
      db.tokens[token] = user.id;
      await saveDb();
      return sendJson(res, 200, { token, user: publicUser(user) });
    }

    // ---- نظرة كاملة عند بدء الجلسة ----
    if (method === 'GET' && (route === '/api/bootstrap' || route === '/bootstrap')) {
      const viewer = requireAuth(req, res);
      if (!viewer) return;
      // مدير النظام يحتاج كلمات المرور لتحرير المستخدمين، وغيره لا.
      const isAdmin = rolePermissions(viewer).has('admin.users');
      return sendJson(res, 200, {
        buildings: db.buildings,
        rooms: db.rooms,
        beds: db.beds,
        residents: db.residents,
        requests: db.requests,
        users: isAdmin ? db.users : db.users.map(publicUser),
        contractors: db.contractors,
        contractorWorkers: db.contractorWorkers,
        contractorRequests: db.contractorRequests,
        roles: db.roles,
      });
    }

    // ---- إدارة المستخدمين (مدير النظام فقط) ----
    if (route === '/api/users' || route === '/users') {
      if (method === 'POST') {
        const user = requirePermission(req, res, 'admin.users');
        if (!user) return;
        const body = await readBody(req);
        const username = String(body.username || '').trim();
        const name = String(body.name || '').trim();
        const password = String(body.password || '');
        if (!name) return sendError(res, 400, 'يرجى إدخال الاسم');
        if (!username) return sendError(res, 400, 'يرجى إدخال اسم المستخدم');
        const id = body.id ? String(body.id) : 'u' + Date.now() + Math.floor(Math.random() * 1000);
        const taken = db.users.some(
          (u) => u.id !== id && u.username.toLowerCase() === username.toLowerCase()
        );
        if (taken) return sendError(res, 409, 'اسم المستخدم مستخدم مسبقاً');
        const existing = db.users.find((u) => u.id === id);
        if (!existing && !password) return sendError(res, 400, 'يرجى إدخال كلمة المرور');
        const record = {
          id,
          name,
          username,
          password: password || (existing ? existing.password : ''),
          role: String(body.role || (existing ? existing.role : 'housingSupervisor')),
          roleId: body.roleId != null ? String(body.roleId) : (existing ? existing.roleId : null),
          phone: String(body.phone || '').trim(),
          contractorId: body.contractorId != null ? body.contractorId : (existing ? existing.contractorId : null),
          contractorName: String(body.contractorName || '').trim(),
          companyName: String(body.companyName || (existing ? existing.companyName : '') || '').trim(),
        };
        if (existing) {
          db.users[db.users.indexOf(existing)] = record;
        } else {
          db.users.unshift(record);
        }
        await saveDb();
        return sendJson(res, 200, { user: record, created: !existing });
      }
    }

    const userMatch = route.match(/^\/api\/users\/([^/]+)$/) || route.match(/^\/users\/([^/]+)$/);
    if (method === 'DELETE' && userMatch) {
      const user = requirePermission(req, res, 'admin.users');
      if (!user) return;
      const id = decodeURIComponent(userMatch[1]);
      const before = db.users.length;
      db.users = db.users.filter((u) => u.id !== id);
      if (db.users.length === before) return sendError(res, 404, 'المستخدم غير موجود');
      await saveDb();
      return sendJson(res, 200, { ok: true });
    }

    // ---- قوائم/إنشاء طلبات المتعهدين ----
    if (route === '/api/contractor-requests' || route === '/contractor-requests') {
      if (method === 'GET') {
        if (!requireAuth(req, res)) return;
        return sendJson(res, 200, { data: db.contractorRequests });
      }
      if (method === 'POST') {
        const user = requireAuth(req, res);
        if (!user) return;
        const body = await readBody(req);
        const err =
          body.requestType === 'remove_worker'
            ? validateRemoveWorker(body)
            : validateNewWorker(body);
        if (err) return sendError(res, 400, err);
        const contractor = contractorById(body.contractorId);
        const requestType = body.requestType || 'new_worker';
        const record = {
          id: 'CR-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
          contractorId: body.contractorId,
          contractorName: contractor.name,
          requestType: requestType,
          workerName: String(body.workerName || '').trim(),
          employeeCode: String(body.employeeCode || '').trim(),
          jobTitle: String(body.jobTitle || '').trim(),
          workerCardNumber: String(body.workerCardNumber || '').trim(),
          workerBirthDate: body.workerBirthDate || null,
          workerBirthPlace: String(body.workerBirthPlace || '').trim(),
          buildingId: null,
          bedId: null,
          reason: String(body.reason || '').trim(),
          // الإضافة تبدأ من مشرف الأمن، والاستبعاد يبدأ من مراقب السكن.
          stage: requestType === 'remove_worker' ? 'housing' : 'security',
          createdAt: new Date().toISOString(),
          housingApprover: '',
          securityApprover: '',
          visitorApprover: '',
          reviewedAt: null,
          reviewNotes: '',
          submittedBy: user.username,
        };
        db.contractorRequests.unshift(record);
        await saveDb();
        return sendJson(res, 201, record);
      }
    }

    // ---- إجراءات على طلب محدد ----
    const actionMatch = route.match(/^\/api\/contractor-requests\/([^/]+)\/([a-z-]+)$/) ||
      route.match(/^\/contractor-requests\/([^/]+)\/([a-z-]+)$/);
    if (method === 'POST' && actionMatch) {
      const [, id, action] = actionMatch;
      const index = db.contractorRequests.findIndex((r) => r.id === id);
      if (index < 0) return sendError(res, 404, 'الطلب غير موجود');
      const req0 = db.contractorRequests[index];
      const body = await readBody(req);
      const notes = String(body.notes || '').trim();

      if (action === 'approve-housing' || action === 'approve-security' || action === 'approve-visitor') {
        const stageName = action.replace('approve-', '');
        const permByStage = {
          housing: 'requests.supervise',
          security: 'requests.security',
          visitor: 'requests.visitor',
        };
        const stageLabelByStage = {
          housing: 'مراقب السكن',
          security: 'مشرف الأمن',
          visitor: 'مراقب الزوار',
        };
        const user = requirePermission(req, res, permByStage[stageName]);
        if (!user) return;
        if (req0.stage !== stageName) {
          return sendError(res, 409, 'الطلب ليس بانتظار ' + stageLabelByStage[stageName]);
        }

        // مرحلة التنفيذ: آخر مرحلة في كل مسار.
        const isAdd = req0.requestType !== 'remove_worker';
        const isExecutionStage = isAdd ? stageName === 'housing' : stageName === 'visitor';

        if (stageName === 'visitor' && isAdd) {
          const code = String(body.employeeCode || '').trim();
          if (!code) return sendError(res, 400, 'يرجى إدخال كود الموظف قبل الاعتماد');
          req0.employeeCode = code;
          if (req0.workerBirthDate) {
            const bd = new Date(req0.workerBirthDate);
            if (!isNaN(bd.getTime())) {
              const now = new Date();
              let age = now.getFullYear() - bd.getFullYear();
              if (now.getMonth() < bd.getMonth() ||
                  (now.getMonth() === bd.getMonth() && now.getDate() < bd.getDate())) {
                age--;
              }
              if (age < 18) return sendError(res, 409, 'لا يسمح بإضافة موظف أقل من 18 عاماً');
            }
          }
        }

        if (isExecutionStage) {
          if (isAdd) {
            if (freeBedCount(req0.contractorId) <= 0) {
              return sendError(res, 409, 'لا يوجد فراغ في السكن التابع للمتعهد');
            }
            const result = createResident(req0);
            if (result.error) return sendError(res, 409, result.error);
            db.residents.unshift(result.resident);
            req0.bedId = result.bedId;
          } else {
            const names = new Set([req0.workerName]);
            if (req0.employeeCode) names.add(req0.employeeCode);
            db.residents = db.residents.filter(
              (r) =>
                !(r.contractorId === req0.contractorId &&
                  (names.has(r.name) || names.has(r.employeeCode)))
            );
          }
        }

        if (stageName === 'housing') {
          req0.housingApprover = user.name;
          req0.stage = isAdd ? 'done' : 'security';
        } else if (stageName === 'security') {
          req0.securityApprover = user.name;
          req0.stage = 'visitor';
        } else {
          req0.visitorApprover = user.name;
          req0.stage = isAdd ? 'housing' : 'done';
        }
        req0.reviewedAt = new Date().toISOString();
        req0.reviewNotes = notes;
        await saveDb();
        return sendJson(res, 200, req0);
      }

      if (action === 'reject') {
        const user = requireAuth(req, res);
        if (!user) return;
        const perms = rolePermissions(user);
        if (!perms.has('requests.supervise') &&
            !perms.has('requests.security') &&
            !perms.has('requests.visitor')) {
          return sendError(res, 403, 'لا تملك صلاحية هذا الإجراء');
        }
        if (req0.stage === 'done' || req0.stage === 'rejected') {
          return sendError(res, 409, 'الطلب مغلق مسبقاً');
        }
        const noteByStage = {
          housing: 'مرفوض من مراقب السكن',
          security: 'مرفوض من مشرف الأمن',
          visitor: 'مرفوض من مراقب الزوار',
        };
        const defaultNote = noteByStage[req0.stage] || 'مرفوض';
        req0.stage = 'rejected';
        req0.reviewedAt = new Date().toISOString();
        req0.reviewNotes = notes || defaultNote;
        await saveDb();
        return sendJson(res, 200, req0);
      }
    }

    sendError(res, 404, 'المسار غير موجود: ' + method + ' ' + route);
  } catch (e) {
    console.error('خطأ:', e);
    sendError(res, 500, 'خطأ داخلي في الخادم');
  }
});

async function main() {
  store = await createStore();
  db = store.get();
  server.listen(PORT, '0.0.0.0', () => {
    console.log('خادم إدارة السكن يعمل على المنفذ ' + PORT);
    console.log('مثال: http://127.0.0.1:' + PORT + '/api/health');
  });
}

main().catch((e) => {
  console.error('فشل بدء الخادم:', e);
  process.exit(1);
});
