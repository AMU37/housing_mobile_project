import 'package:flutter/material.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => DefaultTabController(
        length: 5,
        child: Scaffold(
          backgroundColor: canvas,
          appBar: AppBar(
            title: const Text('إدارة المستخدمين والأدوار', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: navy)),
            actions: [
              IconButton(
                tooltip: 'استعادة البيانات الأصلية',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: () => _confirmReset(context),
              ),
            ],
            bottom: const TabBar(
              labelColor: teal,
              unselectedLabelColor: muted,
              indicatorColor: teal,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'المستخدمون'),
                Tab(text: 'الأدوار'),
                Tab(text: 'الصلاحيات'),
                Tab(text: 'المتعهدون'),
                Tab(text: 'الخادم'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _UsersTab(store: store),
              _RolesTab(store: store),
              _PermissionsTab(store: store),
              _ContractorsTab(store: store),
              _ServerTab(store: store),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة مزامنة البيانات'),
        content: const Text('سيتم مسح النسخة المحلية على هذا الجهاز وإعادة تحميل البيانات من الخادم المشترك. لن تتأثر بيانات الخادم. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إعادة المزامنة')),
        ],
      ),
    );
    if (confirmed == true) {
      await store.clearLocalCache();
      await store.refreshFromServer();
    }
  }
}

// ---------------------------------------------------------------- Users

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    final users = List<AppUser>.of(store.users)
      ..sort((a, b) => a.name.compareTo(b.name));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: SectionTitle('المستخدمون', subtitle: '${users.length} حساب')),
          PrimaryAction(label: 'مستخدم جديد', icon: Icons.person_add_alt_1_rounded, compact: true, onPressed: () => _openUserSheet(context, store, null)),
        ]),
        const SizedBox(height: 6),
        ...users.map((u) => _userCard(context, store, u)),
      ],
    );
  }

  Widget _userCard(BuildContext context, HousingStore store, AppUser u) {
    final role = store.roleById(u.effectiveRoleId);
    final roleName = role?.name ?? u.role.label;
    final color = u.isContractor ? const Color(0xFF2673B8) : (u.isSecuritySupervisor ? const Color(0xFF6D28D9) : const Color(0xFF16846B));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(13),
        onTap: () => _openUserSheet(context, store, u),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: color.withOpacity(.12), child: Text(u.initial, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: navy)),
            const SizedBox(height: 3),
            Text('@${u.username}${u.phone.isNotEmpty ? ' • ${u.phone}' : ''}', style: const TextStyle(fontSize: 11, color: muted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(30)),
              child: Text(roleName, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            if (store.currentUser?.id == u.id)
              const Padding(padding: EdgeInsets.only(top: 4), child: Text('أنت', style: TextStyle(fontSize: 10, color: teal, fontWeight: FontWeight.w800))),
          ]),
          IconButton(
            tooltip: 'حذف',
            onPressed: store.currentUser?.id == u.id ? null : () => _confirmDeleteUser(context, store, u),
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFC2414B)),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, HousingStore store, AppUser u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text('هل تريد حذف حساب «${u.name}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC2414B)), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) store.deleteUser(u.id);
  }
}

Future<void> _openUserSheet(BuildContext context, HousingStore store, AppUser? existing) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UserSheet(store: store, existing: existing),
  );
}

class _UserSheet extends StatefulWidget {
  const _UserSheet({required this.store, this.existing});
  final HousingStore store;
  final AppUser? existing;
  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController username;
  late final TextEditingController password;
  late final TextEditingController phone;
  late String roleId;
  String? contractorId;
  String error = '';

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    name = TextEditingController(text: u?.name ?? '');
    username = TextEditingController(text: u?.username ?? '');
    password = TextEditingController(text: u?.password ?? '');
    phone = TextEditingController(text: u?.phone ?? '');
    roleId = u?.effectiveRoleId ?? widget.store.roles.first.id;
    contractorId = u?.contractorId;
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
    phone.dispose();
    super.dispose();
  }

  bool get _roleHasContractor =>
      widget.store.roleById(roleId)?.permissionIds.contains('contractor.portal') ?? false;

  void _save() {
    if (!formKey.currentState!.validate()) return;
    final role = widget.store.userRoleForRoleId(roleId);
    final contractor = widget.store.contractorById(contractorId);
    setState(() => error = '');
    if (widget.existing == null) {
      final err = widget.store.createUser(
        name: name.text,
        username: username.text,
        password: password.text,
        role: role,
        roleId: roleId,
        phone: phone.text,
        contractorId: _roleHasContractor ? contractorId : null,
        contractorName: _roleHasContractor ? (contractor?.name ?? '') : '',
      );
      if (err != null) {
        setState(() => error = err);
        return;
      }
    } else {
      if (widget.store.usernameTaken(username.text, exceptId: widget.existing!.id)) {
        setState(() => error = 'اسم المستخدم مستخدم مسبقاً');
        return;
      }
      widget.store.updateUser(AppUser(
        id: widget.existing!.id,
        name: name.text.trim(),
        username: username.text.trim(),
        password: password.text,
        role: role,
        roleId: roleId,
        phone: phone.text.trim(),
        contractorId: _roleHasContractor ? contractorId : null,
        contractorName: _roleHasContractor ? (contractor?.name ?? '') : '',
      ));
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(widget.existing == null ? 'تمت إضافة المستخدم' : 'تم تحديث المستخدم')));
  }

  @override
  Widget build(BuildContext context) {
    final contractors = widget.store.contractors;
    return Container(
      height: MediaQuery.of(context).size.height * .9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 22),
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(5)))),
              const SizedBox(height: 18),
              Text(widget.existing == null ? 'مستخدم جديد' : 'تعديل المستخدم', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 5),
              const Text('حدّد اسم الدخول والدور الذي يحدد صلاحيات المستخدم.', style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 18),
              _field(name, 'الاسم الكامل', Icons.person_outline_rounded, requiredField: true),
              const SizedBox(height: 10),
              _field(username, 'اسم المستخدم', Icons.account_circle_outlined, requiredField: true),
              const SizedBox(height: 10),
              _field(password, 'كلمة المرور', Icons.lock_outline_rounded, requiredField: true),
              const SizedBox(height: 10),
              _field(phone, 'رقم الجوال', Icons.phone_outlined),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: roleId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الدور', prefixIcon: Icon(Icons.verified_user_outlined)),
                items: widget.store.roles.map((r) => DropdownMenuItem(value: r.id, child: Text('${r.name} (${r.permissionIds.length} صلاحية)'))).toList(),
                onChanged: (v) => setState(() => roleId = v ?? roleId),
              ),
              if (_roleHasContractor) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: contractorId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المتعهد/المقاول المرتبط', prefixIcon: Icon(Icons.handshake_outlined)),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('بدون ربط')),
                    ...contractors.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} • ${c.typeLabel}', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => contractorId = (v == null || v.isEmpty) ? null : v),
                ),
              ],
              if (error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFC2414B).withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                  child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFC2414B), fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 22),
              PrimaryAction(label: widget.existing == null ? 'إضافة المستخدم' : 'حفظ التعديلات', icon: Icons.check_circle_outline_rounded, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool requiredField = false}) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    validator: requiredField ? (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null : null,
  );
}

// ---------------------------------------------------------------- Roles

class _RolesTab extends StatelessWidget {
  const _RolesTab({required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    final roles = store.roles;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: SectionTitle('الأدوار', subtitle: '${roles.length} دور')),
          PrimaryAction(label: 'دور جديد', icon: Icons.add_rounded, compact: true, onPressed: () => _openRoleSheet(context, store, null)),
        ]),
        const SizedBox(height: 6),
        ...roles.map((r) => _roleCard(context, store, r)),
      ],
    );
  }

  Widget _roleCard(BuildContext context, HousingStore store, AppRole role) {
    final users = store.userCountForRole(role.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _openRoleSheet(context, store, role),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: teal.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.verified_user_rounded, size: 20, color: teal)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(role.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: navy)),
                if (role.isSystem) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: navy.withOpacity(.08), borderRadius: BorderRadius.circular(6)), child: const Text('نظامي', style: TextStyle(fontSize: 9, color: navy, fontWeight: FontWeight.w800))),
                ],
              ]),
              Text(role.description.isEmpty ? 'بدون وصف' : role.description, style: const TextStyle(fontSize: 11, color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            IconButton(
              tooltip: 'حذف',
              onPressed: role.isSystem ? null : () => _confirmDeleteRole(context, store, role),
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: role.isSystem ? const Color(0xFFC3CBD6) : const Color(0xFFC2414B)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _chip(Icons.people_alt_outlined, '$users مستخدم'),
            const SizedBox(width: 8),
            _chip(Icons.key_outlined, '${role.permissionIds.length} صلاحية'),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(9)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: muted), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700))]),
  );

  Future<void> _confirmDeleteRole(BuildContext context, HousingStore store, AppRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الدور'),
        content: Text('هل تريد حذف الدور «${role.name}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC2414B)), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = store.deleteRole(role.id);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: const Color(0xFFC2414B)));
    }
  }
}

Future<void> _openRoleSheet(BuildContext context, HousingStore store, AppRole? existing) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoleSheet(store: store, existing: existing),
  );
}

class _RoleSheet extends StatefulWidget {
  const _RoleSheet({required this.store, this.existing});
  final HousingStore store;
  final AppRole? existing;
  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController description;
  late Set<String> selected;
  String error = '';

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.existing?.name ?? '');
    description = TextEditingController(text: widget.existing?.description ?? '');
    selected = Set<String>.of(widget.existing?.permissionIds ?? const <String>{});
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Map<String, List<AppPermission>> get _grouped {
    final map = <String, List<AppPermission>>{};
    for (final p in appPermissionCatalog) {
      map.putIfAbsent(p.group, () => []).add(p);
    }
    return map;
  }

  void _save() {
    if (!formKey.currentState!.validate()) return;
    setState(() => error = '');
    if (widget.existing == null) {
      widget.store.addRole(name: name.text, description: description.text, permissionIds: selected);
    } else {
      widget.store.updateRole(widget.existing!.copyWith(
        name: name.text.trim(),
        description: description.text.trim(),
        permissionIds: Set<String>.of(selected),
      ));
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(widget.existing == null ? 'تم إضافة الدور' : 'تم تحديث الدور')));
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Container(
      height: MediaQuery.of(context).size.height * .92,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 22),
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(5)))),
              const SizedBox(height: 18),
              Text(widget.existing == null ? 'دور جديد' : 'تعديل الدور', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 5),
              const Text('اختر الصلاحيات التي يمنحها هذا الدور.', style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 18),
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم الدور', prefixIcon: Icon(Icons.verified_user_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null),
              const SizedBox(height: 10),
              TextFormField(controller: description, decoration: const InputDecoration(labelText: 'الوصف (اختياري)', prefixIcon: Icon(Icons.notes_rounded))),
              const SizedBox(height: 16),
              ...grouped.entries.map((e) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 6),
                  child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: teal)),
                ),
                ...e.value.map((p) => CheckboxListTile(
                  value: selected.contains(p.id),
                  onChanged: (v) => setState(() => v == true ? selected.add(p.id) : selected.remove(p.id)),
                  title: Text(p.label, style: const TextStyle(fontSize: 13, color: navy, fontWeight: FontWeight.w700)),
                  subtitle: Text(p.id, style: const TextStyle(fontSize: 10, color: muted)),
                  activeColor: teal,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                )),
              ])),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFC2414B), fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 14),
              PrimaryAction(label: widget.existing == null ? 'إضافة الدور' : 'حفظ التعديلات', icon: Icons.check_circle_outline_rounded, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Server

class _ServerTab extends StatefulWidget {
  const _ServerTab({required this.store});
  final HousingStore store;
  @override
  State<_ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<_ServerTab> {
  late final TextEditingController _server;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: widget.store.baseUrl);
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _server.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    await widget.store.setBaseUrl(url);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _server.text = widget.store.baseUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.store.isOnline ? 'تم الاتصال بالخادم وتحديث العنوان' : 'تم حفظ العنوان، لكن تعذّر الاتصال بالخادم'),
      backgroundColor: widget.store.isOnline ? teal : const Color(0xFFC2414B),
    ));
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    await widget.store.refreshFromServer();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final online = widget.store.isOnline;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('إعدادات الخادم', subtitle: 'اتصال التطبيق بالخادم المشترك'),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 20, color: online ? const Color(0xFF16846B) : const Color(0xFFC2414B)),
                  const SizedBox(width: 8),
                  Text(online ? 'متصل بالخادم' : 'غير متصل بالخادم', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: navy)),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الخادم',
                    hintText: 'https://example.onrender.com/api',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يجب أن تشير جميع أجهزة المتعهدين ومراقبي السكن إلى نفس عنوان الخادم لوصول الطلبات بينها.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                if (widget.store.lastSyncError != null) ...[
                  const SizedBox(height: 10),
                  Text(widget.store.lastSyncError!, style: const TextStyle(fontSize: 11, color: Color(0xFFC2414B), fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 16),
                PrimaryAction(
                  label: _busy ? 'جارٍ الحفظ...' : 'حفظ ومزامنة',
                  icon: Icons.save_rounded,
                  onPressed: _busy ? null : _save,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: (_busy || widget.store.isSyncing) ? null : _sync,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: Text(widget.store.isSyncing ? 'جارٍ المزامنة...' : 'مزامنة الآن'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    side: const BorderSide(color: Color(0xFFB7E0DB)),
                  ),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Permissions

class _PermissionsTab extends StatelessWidget {
  const _PermissionsTab({required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<AppPermission>>{};
    for (final p in appPermissionCatalog) {
      grouped.putIfAbsent(p.group, () => []).add(p);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('كتالوج الصلاحيات', subtitle: 'الصلاحيات المتاحة لمنحها للأدوار'),
        const SizedBox(height: 6),
        ...grouped.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: teal)),
                  const SizedBox(height: 8),
                  ...e.value.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.key_rounded, size: 15, color: muted)),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.label, style: const TextStyle(fontSize: 13, color: navy, fontWeight: FontWeight.w700)),
                            Text(p.id, style: const TextStyle(fontSize: 10, color: muted)),
                          ])),
                          Text('${store.roles.where((r) => r.permissionIds.contains(p.id)).length} دور', style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700)),
                        ]),
                      )),
                ]),
              ),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------- Contractors

const List<List<String>> _contractorTypes = [
  ['cleaning', 'نظافة'],
  ['catering', 'مطعم وتغذية'],
  ['security', 'أمن وحراسة'],
  ['laundry', 'مغسلة'],
  ['maintenance', 'صيانة عامة'],
  ['electrical', 'كهرباء وإنارة'],
  ['hvac', 'تكييف وتبريد'],
  ['general', 'مقاول عام'],
  ['agriculture', 'زراعة'],
  ['labor', 'عمالة'],
  ['services', 'خدمات'],
  ['other', 'أخرى'],
];

class _ContractorsTab extends StatelessWidget {
  const _ContractorsTab({required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    final contractors = store.contractors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: SectionTitle('المتعهدون والمقاولون', subtitle: '${contractors.length} جهة')),
          PrimaryAction(label: 'متعهد جديد', icon: Icons.add_business_rounded, compact: true, onPressed: () => _openContractorSheet(context, store, null)),
        ]),
        const SizedBox(height: 6),
        ...contractors.map((c) => _contractorCard(context, store, c)),
      ],
    );
  }

  Widget _contractorCard(BuildContext context, HousingStore store, Contractor c) {
    final workers = store.workerCountForContractor(c.id);
    final quota = c.bedQuota == 0 ? 'غير محدد' : '${c.bedQuota}';
    final buildings = store.buildingsForContractor(c.id).map((b) => b.name).join(' • ');
    final hasUser = store.contractorUserCount(c.id) > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _openContractorSheet(context, store, c),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF2673B8).withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.handshake_outlined, size: 20, color: Color(0xFF2673B8))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: navy)),
              Text('${c.typeLabel} • حصة الأسرّة: $quota', style: const TextStyle(fontSize: 11, color: muted)),
            ])),
            IconButton(
              tooltip: 'حذف',
              onPressed: () => _confirmDeleteContractor(context, store, c),
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: const Color(0xFFC2414B)),
            ),
          ]),
          if (buildings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('السكن: $buildings', style: const TextStyle(fontSize: 11, color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(children: [
            _chip(Icons.groups_2_outlined, '$workers عامل'),
            const SizedBox(width: 8),
            _chip(hasUser ? Icons.check_circle_outline_rounded : Icons.no_accounts_outlined, hasUser ? 'له حساب دخول' : 'بدون حساب'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _openLinkWorkersSheet(context, store, c),
              icon: const Icon(Icons.link_rounded, size: 17),
              label: const Text('ربط/إدارة العمال', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(foregroundColor: teal, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), side: const BorderSide(color: Color(0xFFB7E0DB))),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(9)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: muted), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700))]),
  );

  Future<void> _confirmDeleteContractor(BuildContext context, HousingStore store, Contractor c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المتعهد'),
        content: Text('هل تريد حذف «${c.name}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC2414B)), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = store.deleteContractor(c.id);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: const Color(0xFFC2414B)));
    }
  }
}

Future<void> _openContractorSheet(BuildContext context, HousingStore store, Contractor? existing) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContractorSheet(store: store, existing: existing),
  );
}

class _ContractorSheet extends StatefulWidget {
  const _ContractorSheet({required this.store, this.existing});
  final HousingStore store;
  final Contractor? existing;
  @override
  State<_ContractorSheet> createState() => _ContractorSheetState();
}

class _ContractorSheetState extends State<_ContractorSheet> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController quota;
  late final TextEditingController username;
  late final TextEditingController password;
  late String type;
  late Set<String> buildingIds;
  bool createLogin = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    name = TextEditingController(text: c?.name ?? '');
    phone = TextEditingController(text: c?.contactPhone ?? '');
    email = TextEditingController(text: c?.contactEmail ?? '');
    quota = TextEditingController(text: (c?.bedQuota ?? 0) == 0 ? '' : '${c!.bedQuota}');
    type = c?.contractorType ?? 'cleaning';
    buildingIds = Set<String>.of(c?.buildingIds ?? const <String>[]);
    username = TextEditingController();
    password = TextEditingController(text: '123456');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    quota.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  void _save() {
    if (!formKey.currentState!.validate()) return;
    setState(() => error = '');
    final q = int.tryParse(quota.text.trim()) ?? 0;
    if (widget.existing == null) {
      final err = widget.store.createContractor(
        name: name.text,
        contractorType: type,
        phone: phone.text,
        email: email.text,
        buildingIds: buildingIds.toList(),
        bedQuota: q,
      );
      if (err != null) {
        setState(() => error = err);
        return;
      }
      final created = widget.store.contractors.last;
      if (createLogin) {
        final uerr = widget.store.createUser(
          name: created.name,
          username: username.text,
          password: password.text,
          role: UserRole.contractor,
          roleId: 'r_contractor',
          phone: created.contactPhone,
          contractorId: created.id,
          contractorName: created.name,
        );
        if (uerr != null) {
          setState(() => error = 'تم إنشاء المتعهد، لكن حساب الدخول: $uerr');
          return;
        }
      }
    } else {
      widget.store.updateContractor(widget.existing!.copyWith(
        name: name.text.trim(),
        contractorType: type,
        contactPhone: phone.text.trim(),
        contactEmail: email.text.trim(),
        buildingIds: buildingIds.toList(),
        bedQuota: q,
      ));
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(widget.existing == null ? 'تمت إضافة المتعهد/المقاول' : 'تم تحديث بيانات المتعهد')));
  }

  @override
  Widget build(BuildContext context) {
    final buildings = widget.store.buildings;
    return Container(
      height: MediaQuery.of(context).size.height * .92,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 22),
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(5)))),
              const SizedBox(height: 18),
              Text(widget.existing == null ? 'متعهد/مقاول جديد' : 'تعديل المتعهد', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 5),
              const Text('حدّد الاسم والنوع والسكن المخصص وحصة الأسرّة، ثم اربط العمال.', style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 18),
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المتعهد/المقاول', prefixIcon: Icon(Icons.business_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع الخدمة', prefixIcon: Icon(Icons.category_outlined)),
                items: _contractorTypes.map((t) => DropdownMenuItem(value: t[0], child: Text(t[1]))).toList(),
                onChanged: (v) => setState(() => type = v ?? type),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: phone, decoration: const InputDecoration(labelText: 'الجوال', prefixIcon: Icon(Icons.phone_outlined)))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: quota, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حصة الأسرّة', prefixIcon: Icon(Icons.bed_outlined)))),
              ]),
              const SizedBox(height: 10),
              TextFormField(controller: email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)', prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 14),
              const Text('السكن المخصص', style: TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: buildings.map((b) {
                final on = buildingIds.contains(b.id);
                return InkWell(
                  onTap: () => setState(() => on ? buildingIds.remove(b.id) : buildingIds.add(b.id)),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: on ? teal.withOpacity(.12) : canvas, borderRadius: BorderRadius.circular(30), border: Border.all(color: on ? teal : line)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined, size: 15, color: on ? teal : muted),
                      const SizedBox(width: 6),
                      Text(b.name, style: TextStyle(fontSize: 11, color: on ? teal : muted, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                );
              }).toList()),
              if (widget.existing == null) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: createLogin,
                  onChanged: (v) => setState(() => createLogin = v ?? false),
                  title: const Text('إنشاء حساب دخول للمتعهد', style: TextStyle(fontSize: 13, color: navy, fontWeight: FontWeight.w800)),
                  subtitle: const Text('يستطيع بعدها الدخول لإدارة عماله وتقديم الطلبات', style: TextStyle(fontSize: 11, color: muted)),
                  activeColor: teal,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (createLogin) ...[
                  const SizedBox(height: 6),
                  TextFormField(controller: username, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.account_circle_outlined)), validator: createLogin ? (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null : null),
                  const SizedBox(height: 10),
                  TextFormField(controller: password, decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline_rounded)), validator: createLogin ? (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null : null),
                ],
              ],
              if (error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFC2414B).withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                  child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFC2414B), fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 22),
              PrimaryAction(label: widget.existing == null ? 'إضافة المتعهد' : 'حفظ التعديلات', icon: Icons.check_circle_outline_rounded, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openLinkWorkersSheet(BuildContext context, HousingStore store, Contractor contractor) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LinkWorkersSheet(store: store, contractor: contractor),
  );
}

class _LinkWorkersSheet extends StatefulWidget {
  const _LinkWorkersSheet({required this.store, required this.contractor});
  final HousingStore store;
  final Contractor contractor;
  @override
  State<_LinkWorkersSheet> createState() => _LinkWorkersSheetState();
}

class _LinkWorkersSheetState extends State<_LinkWorkersSheet> {
  final search = TextEditingController();
  late Set<String> linked;
  bool onlyUnlinked = true;

  @override
  void initState() {
    super.initState();
    linked = widget.store.workersForContractor(widget.contractor.id).map((r) => r.id).toSet();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<Resident> get _visible {
    final q = search.text.trim().toLowerCase();
    return widget.store.residents.where((r) {
      if (onlyUnlinked && r.contractorId != null && r.contractorId != widget.contractor.id) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) || r.employeeCode.toLowerCase().contains(q);
    }).toList();
  }

  void _commit() {
    final mineIds = widget.store.workersForContractor(widget.contractor.id).map((r) => r.id).toSet();
    widget.store.linkWorkersToContractor(widget.contractor.id, linked.difference(mineIds));
    for (final id in mineIds.difference(linked)) {
      widget.store.assignResidentToContractor(id, null);
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text('تم تحديث عمال «${widget.contractor.name}» — ${linked.length} عامل')));
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Container(
      height: MediaQuery.of(context).size.height * .92,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(5))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ربط العمال بـ «${widget.contractor.name}»', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 4),
              Text('المُختار: ${linked.length} عامل — حصة الأسرّة: ${widget.contractor.bedQuota == 0 ? 'غير محددة' : widget.contractor.bedQuota}', style: const TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 12),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'بحث بالاسم أو الرقم الوظيفي', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: onlyUnlinked,
                onChanged: (v) => setState(() => onlyUnlinked = v),
                title: const Text('إظهار غير المرتبطين فقط', style: TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w700)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: teal,
              ),
            ]),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(title: 'لا يوجد عمال مطابقون', subtitle: 'عدّل البحث أو ألغِ خيار «غير المرتبطين فقط»', icon: Icons.groups_outlined)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final r = items[i];
                      final sel = linked.contains(r.id);
                      final other = r.contractorId != null && r.contractorId != widget.contractor.id;
                      final otherName = other ? (widget.store.contractorById(r.contractorId)?.name ?? 'متعهد آخر') : '';
                      return CheckboxListTile(
                        value: sel,
                        onChanged: (v) => setState(() => v == true ? linked.add(r.id) : linked.remove(r.id)),
                        title: Text(r.name, style: const TextStyle(fontSize: 13, color: navy, fontWeight: FontWeight.w700)),
                        subtitle: Text('${r.employeeCode.isEmpty ? '—' : r.employeeCode}${r.jobTitle.isEmpty ? '' : ' • ${r.jobTitle}'}${other ? ' • مرتبط بـ $otherName' : ''}', style: TextStyle(fontSize: 10, color: other ? const Color(0xFFB27C18) : muted)),
                        activeColor: teal,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: PrimaryAction(label: 'حفظ الربط', icon: Icons.save_rounded, onPressed: _commit),
          ),
        ]),
      ),
    );
  }
}

