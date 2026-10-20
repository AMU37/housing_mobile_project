/**
 * طبقة تخزين موحّدة لخادم إدارة السكن.
 *
 * - إذا وُجد DATABASE_URL (مثال: Supabase/PostgreSQL) → تخزين دائم في Postgres.
 * - وإلا → تخزين في ملف data.json (للتطوير المحلي فقط).
 *
 * كل حالة الخادم تُخزّن كوثيقة JSON واحدة في جدول kv_store، لذا لا حاجة
 * لتعديل منطق العمليات في server.js.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const DATA_FILE = path.join(__dirname, 'data.json');
const SEED_FILE = path.join(__dirname, 'seed.json');
const DATABASE_URL = (process.env.DATABASE_URL || '').trim();
const STATE_KEY = 'housing_state_v1';

// تعريف الأدوار النظامية الأساسية — يُستخدم لترقية حالات مخزّنة قديمة
// (إضافة دور أو صلاحية جديدة) دون المساس بالبيانات الموجودة.
const SYSTEM_ROLES = [
  {
    id: 'r_visitor',
    name: 'مراقب الزوار',
    description: 'يدقّق بيانات العامل (كود الموظف والعمر) ويعتمد الطلبات',
    isSystem: true,
    permissionIds: ['operations.view', 'requests.visitor'],
  },
];

// صلاحيات جديدة تُضاف للأدوار القائمة إن لم تكن موجودة.
const ROLE_PERMISSION_ADDITIONS = {
  r_admin: ['requests.visitor'],
};

// حسابات نظامية أساسية تُضاف فقط إن لم يكن الحساب موجوداً (بالاسم).
const SYSTEM_USERS = [
  {
    id: 'demo-visitor-00000000000000000001',
    name: 'مراقب الزوار',
    username: 'visitor',
    password: '123456',
    role: 'visitorSupervisor',
    roleId: 'r_visitor',
  },
];

function ensureRoles(data) {
  if (!Array.isArray(data.roles)) data.roles = [];
  let changed = false;
  for (const role of SYSTEM_ROLES) {
    if (!data.roles.some((r) => r.id === role.id)) {
      data.roles.push(JSON.parse(JSON.stringify(role)));
      changed = true;
    }
  }
  for (const [roleId, perms] of Object.entries(ROLE_PERMISSION_ADDITIONS)) {
    const role = data.roles.find((r) => r.id === roleId);
    if (!role) continue;
    if (!Array.isArray(role.permissionIds)) role.permissionIds = [];
    for (const p of perms) {
      if (!role.permissionIds.includes(p)) {
        role.permissionIds.push(p);
        changed = true;
      }
    }
  }
  if (!Array.isArray(data.users)) data.users = [];
  for (const u of SYSTEM_USERS) {
    const exists = data.users.some(
      (x) => x.username && x.username.toLowerCase() === u.username.toLowerCase()
    );
    if (!exists) {
      data.users.push(JSON.parse(JSON.stringify(u)));
      changed = true;
    }
  }
  return changed;
}

function loadSeed() {
  if (!fs.existsSync(SEED_FILE)) {
    throw new Error('لم يُعثر على seed.json — شغّل أولاً: dart run tool/export_seed.dart');
  }
  const seed = JSON.parse(fs.readFileSync(SEED_FILE, 'utf8'));
  return {
    buildings: seed.buildings || [],
    rooms: seed.rooms || [],
    beds: seed.beds || [],
    residents: seed.residents || [],
    requests: seed.requests || [],
    users: seed.users || [],
    contractors: seed.contractors || [],
    contractorWorkers: seed.contractorWorkers || [],
    contractorRequests: seed.contractorRequests || [],
    roles: seed.roles || [],
    tokens: {},
  };
}

// ---------------------------------------------------------------------------
// وضع الملف المحلي (بدون DATABASE_URL)
// ---------------------------------------------------------------------------

function fileLoad() {
  if (fs.existsSync(DATA_FILE)) {
    try {
      const data = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
      if (ensureRoles(data)) fileWrite(data);
      return data;
    } catch (e) {
      console.error('تعذّر قراءة data.json، سيتم إنشاء نسخة جديدة:', e.message);
    }
  }
  const fresh = loadSeed();
  ensureRoles(fresh);
  fileWrite(fresh);
  return fresh;
}

function fileWrite(data) {
  const tmp = DATA_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(data));
  fs.renameSync(tmp, DATA_FILE);
}

// ---------------------------------------------------------------------------
// وضع PostgreSQL (Supabase) — DATABASE_URL
// ---------------------------------------------------------------------------

let pool = null;

function getPool() {
  if (pool) return pool;
  const { Pool } = require('pg');
  const needsSsl = !/localhost|127\.0\.0\.1/.test(DATABASE_URL);
  pool = new Pool({
    connectionString: DATABASE_URL,
    ssl: needsSsl ? { rejectUnauthorized: false } : false,
  });
  return pool;
}

async function pgInit() {
  const p = getPool();
  await p.query(
    'CREATE TABLE IF NOT EXISTS kv_store (key TEXT PRIMARY KEY, value JSONB NOT NULL, updated_at TIMESTAMPTZ NOT NULL DEFAULT now())'
  );
}

async function pgLoad() {
  const p = getPool();
  const { rows } = await p.query('SELECT value FROM kv_store WHERE key = $1', [STATE_KEY]);
  if (rows.length) {
    const data = rows[0].value;
    if (ensureRoles(data)) await pgWrite(data);
    return data;
  }
  const fresh = loadSeed();
  ensureRoles(fresh);
  await pgWrite(fresh);
  return fresh;
}

async function pgWrite(data) {
  const p = getPool();
  await p.query(
    'INSERT INTO kv_store (key, value, updated_at) VALUES ($1, $2, now()) ' +
      'ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()',
    [STATE_KEY, JSON.stringify(data)]
  );
}

// ---------------------------------------------------------------------------
// واجهة موحّدة
// ---------------------------------------------------------------------------

async function createStore() {
  if (DATABASE_URL) {
    await pgInit();
    let current = await pgLoad();
    console.log('التخزين: PostgreSQL (دائم)');
    return {
      mode: 'postgres',
      get: () => current,
      save: async (next) => {
        if (next) current = next;
        await pgWrite(current);
      },
    };
  }
  let current = fileLoad();
  console.log('التخزين: ملف محلي data.json (للتطوير)');
  return {
    mode: 'file',
    get: () => current,
    save: async (next) => {
      if (next) current = next;
      fileWrite(current);
    },
  };
}

module.exports = { createStore, loadSeed };
