import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../data/demo_data.dart';
import '../models/housing_models.dart';
import '../services/housing_api.dart';

class HousingStore extends ChangeNotifier {
  HousingStore()
      : buildings = List<BuildingUnit>.of(demoBuildings),
        rooms = List<RoomUnit>.of(demoRooms),
        beds = List<BedUnit>.of(demoBeds),
        residents = List<Resident>.of(demoResidents),
        requests = List<HousingRequest>.of(demoRequests),
        rotations = <BedRotation>[],
        users = List<AppUser>.of(demoUsers),
        contractors = List<Contractor>.of(demoContractors),
        contractorWorkers = List<ContractorWorker>.of(demoContractorWorkers),
        contractorRequests = List<ContractorRequest>.of(demoContractorRequests),
        roles = List<AppRole>.of(defaultRoles) {
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      _skipSave = true;
      notifyListeners();
      _skipSave = false;
    });
    _init();
  }

  Timer? _ticker;
  Timer? _saveTimer;
  Timer? _syncTimer;
  bool _skipSave = false;
  bool _restored = false;

  static const String _storageKey = 'housing_state_v2';
  static const int _schemaVersion = 2;

  /// هل وُجدت بيانات محفوظة سابقاً على الجهاز (تم استرجاعها)؟
  bool get hasPersistedState => _restored;

  // ---- المزامنة مع الخادم المشترك ----
  HousingApi? _api;
  bool _online = false;
  bool _syncing = false;
  bool _syncInFlight = false;
  bool _bootstrapped = false;
  String? _lastSyncError;
  String _baseUrl = AppConfig.defaultBaseUrl;

  /// عنوان الخادم الحالي (قابل للتغيير من شاشة الدخول).
  String get baseUrl => _baseUrl;

  /// هل الاجهاز متصل بالخادم المشترك؟
  bool get isOnline => _online;

  /// هل يجري تزامن الآن؟
  bool get isSyncing => _syncing;

  /// هل حمّلنا البيانات الكاملة من الخادم؟
  bool get isBootstrapped => _bootstrapped;

  /// آخر رسالة خطأ تزامن (تُعرض للمستخدم عند الحاجة).
  String? get lastSyncError => _lastSyncError;

  /// هل توجد طلبات أُنشئت دون اتصال وتنتظر الرفع للخادم؟
  bool get hasPendingUploads => _pendingUpload.isNotEmpty;

  Future<void> _init() async {
    await _restore();
    await _loadBaseUrl();
    _api = HousingApi(baseUrl: _baseUrl);
    if (await _api!.checkHealth()) {
      _online = true;
      _startSyncTimer();
      notifyListeners();
      await syncNow();
    }
  }

  Future<void> _loadBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(AppConfig.baseUrlPrefsKey);
      if (saved != null && saved.trim().isNotEmpty) _baseUrl = saved.trim();
    } catch (_) {}
  }

  /// يضبط عنوان الخادم (يُحفظ على الجهاز) ويعيد الاتصال.
  Future<void> setBaseUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    _baseUrl = normalized;
    _api = HousingApi(baseUrl: _baseUrl);
    _online = false;
    _bootstrapped = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.baseUrlPrefsKey, _baseUrl);
    } catch (_) {}
    if (await _api!.checkHealth()) {
      _online = true;
      _startSyncTimer();
      notifyListeners();
      await syncNow();
    } else {
      _lastSyncError = 'تعذّر الاتصال بالخادم على العنوان: $_baseUrl';
      notifyListeners();
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => syncNow());
  }

  /// تحديث دوري يدوي (عند فتح الشاشات الحساسة).
  Future<void> refreshFromServer() => syncNow();

  /// يزامن البيانات: يرفع الطلبات المحلية المعلّقة ثم يجلب الحالة الكاملة.
  Future<void> syncNow() async {
    if (_syncInFlight || _api == null) return;
    _syncInFlight = true;
    _syncing = true;
    _skipSave = true;
    notifyListeners();
    try {
      if (!_online) {
        _online = await _api!.checkHealth();
        if (_online) {
          _startSyncTimer();
        } else {
          _lastSyncError = 'تعذّر الاتصال بالخادم';
        }
      }
      if (_online) {
        await _flushPendingUploads();
        await _pullBootstrap();
        _lastSyncError = null;
      }
    } catch (e) {
      _lastSyncError = e.toString();
      _online = false;
    } finally {
      _skipSave = false;
      _syncing = false;
      _syncInFlight = false;
      notifyListeners();
    }
  }

  Future<void> _pullBootstrap() async {
    final data = await _api!.fetchBootstrapRaw();
    _applyBootstrap(data);
    _bootstrapped = true;
  }

  Future<void> _flushPendingUploads() async {
    if (_pendingUpload.isEmpty) return;
    final remaining = <ContractorUpload>[];
    for (final upload in _pendingUpload) {
      try {
        final created = await _api!.submitContractorRequest(
          contractorId: upload.contractorId,
          type: upload.type,
          workerName: upload.workerName,
          employeeCode: upload.employeeCode,
          jobTitle: upload.jobTitle,
          reason: upload.reason,
          workerCardNumber: upload.workerCardNumber,
          workerBirthDate: upload.workerBirthDate,
          workerBirthPlace: upload.workerBirthPlace,
        );
        final i = contractorRequests.indexWhere((r) => r.id == upload.id);
        if (i >= 0) contractorRequests[i] = created;
      } catch (_) {
        remaining.add(upload);
      }
    }
    _pendingUpload
      ..clear()
      ..addAll(remaining);
  }

  final List<ContractorUpload> _pendingUpload = [];

  void _applyBootstrap(Map<String, dynamic> data) {
    List<Map<String, dynamic>> listOf(String key) =>
        ((data[key] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();

    residents
      ..clear()
      ..addAll(listOf('residents').map(Resident.fromJson));
    requests
      ..clear()
      ..addAll(listOf('requests').map(HousingRequest.fromJson));
    users..clear()..addAll(listOf('users').map(AppUser.fromJson));
    contractors
      ..clear()
      ..addAll(listOf('contractors').map(Contractor.fromJson));
    contractorWorkers
      ..clear()
      ..addAll(listOf('contractorWorkers').map(ContractorWorker.fromJson));
    contractorRequests
      ..clear()
      ..addAll(listOf('contractorRequests').map(ContractorRequest.fromJson));
    roles..clear()..addAll(listOf('roles').map(AppRole.fromJson));

    final id = currentUser?.id;
    if (id != null) {
      currentUser = users.where((u) => u.id == id).firstOrNull ?? currentUser;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _saveTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_skipSave) _schedulePersist();
  }

  void _schedulePersist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _persist);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_toJson()));
    } catch (_) {
      // تجاهل أخطاء الحفظ (بيئة بلا تخزين متاح).
    }
  }

  /// تُحفظ الحالة محلياً كـ«ذاكرة مؤقتة» للعرض دون اتصال فقط.
  /// المصدر الموثوق هو الخادم المشترك.
  Map<String, dynamic> _toJson() => {
        'version': _schemaVersion,
        'residents': residents.map((e) => e.toJson()).toList(),
        'requests': requests.map((e) => e.toJson()).toList(),
        'rotations': rotations.map((e) => e.toJson()).toList(),
        'users': users.map((e) => e.toJson()).toList(),
        'contractors': contractors.map((e) => e.toJson()).toList(),
        'contractorWorkers': contractorWorkers.map((e) => e.toJson()).toList(),
        'contractorRequests': contractorRequests.map((e) => e.toJson()).toList(),
        'roles': roles.map((e) => e.toJson()).toList(),
      };

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if ((data['version'] as int?) != _schemaVersion) return;
      List<Map<String, dynamic>> listOf(String key) =>
          ((data[key] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();

      _skipSave = true;
      residents
        ..clear()
        ..addAll(listOf('residents').map(Resident.fromJson));
      requests
        ..clear()
        ..addAll(listOf('requests').map(HousingRequest.fromJson));
      rotations
        ..clear()
        ..addAll(listOf('rotations').map(BedRotation.fromJson));
      users..clear()..addAll(listOf('users').map(AppUser.fromJson));
      contractors
        ..clear()
        ..addAll(listOf('contractors').map(Contractor.fromJson));
      contractorWorkers
        ..clear()
        ..addAll(listOf('contractorWorkers').map(ContractorWorker.fromJson));
      contractorRequests
        ..clear()
        ..addAll(listOf('contractorRequests').map(ContractorRequest.fromJson));
      roles..clear()..addAll(listOf('roles').map(AppRole.fromJson));
      _skipSave = false;
      _restored = true;
      super.notifyListeners();
    } catch (_) {
      _skipSave = false;
    }
  }

  /// يمسح الذاكرة المؤقتة المحلية فقط. لا يؤثر على بيانات الخادم المشترك.
  Future<void> clearLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
    _restored = false;
    notifyListeners();
  }

  final List<BuildingUnit> buildings;
  final List<RoomUnit> rooms;
  final List<BedUnit> beds;
  final List<Resident> residents;
  final List<HousingRequest> requests;
  final List<BedRotation> rotations;
  final List<AppUser> users;
  final List<Contractor> contractors;
  final List<ContractorWorker> contractorWorkers;
  final List<ContractorRequest> contractorRequests;
  final List<AppRole> roles;

  static const List<AppRole> defaultRoles = [
    AppRole(
      id: 'r_housing',
      name: 'مراقب السكن',
      description: 'يشرف على السكن والسكان ويعتمد طلبات المتعهدين أولياً',
      isSystem: true,
      permissionIds: {
        'dashboard.view',
        'residents.view',
        'housing.view',
        'operations.view',
        'reports.view',
        'residents.manage',
        'housing.manage',
        'requests.supervise',
      },
    ),
    AppRole(
      id: 'r_security',
      name: 'مشرف الأمن',
      description: 'يعتمد الطلبات أمنياً (المرحلة الأمنية)',
      isSystem: true,
      permissionIds: {'operations.view', 'requests.security'},
    ),
    AppRole(
      id: 'r_visitor',
      name: 'مراقب الزوار',
      description: 'يدقّق بيانات العامل (كود الموظف والعمر) ويعتمد الطلبات',
      isSystem: true,
      permissionIds: {'operations.view', 'requests.visitor'},
    ),
    AppRole(
      id: 'r_contractor',
      name: 'متعهد/مقاول',
      description: 'بوابة المتعهد لإدارة عمالته وتقديم الطلبات',
      isSystem: true,
      permissionIds: {'contractor.portal'},
    ),
    AppRole(
      id: 'r_admin',
      name: 'مدير النظام',
      description: 'كامل الصلاحيات بما فيها إدارة المستخدمين والأدوار',
      isSystem: true,
      permissionIds: {
        'dashboard.view',
        'residents.view',
        'housing.view',
        'operations.view',
        'reports.view',
        'residents.manage',
        'housing.manage',
        'requests.supervise',
        'requests.security',
        'requests.visitor',
        'admin.users',
      },
    ),
  ];

  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;
  bool get isSupervisor => currentUser?.isSupervisor ?? false;
  bool get isSecuritySupervisor => currentUser?.isSecuritySupervisor ?? false;
  bool get isVisitorSupervisor => currentUser?.isVisitorSupervisor ?? false;
  bool get isContractor => currentUser?.isContractor ?? false;
  String? get currentContractorId => currentUser?.contractorId;

  AppRole? roleById(String? id) {
    if (id == null) return null;
    for (final r in roles) {
      if (r.id == id) return r;
    }
    return null;
  }

  AppRole? get currentRole => roleById(currentUser?.effectiveRoleId);

  Set<String> get currentPermissions => currentRole?.permissionIds ?? const <String>{};

  bool can(String permissionId) => isLoggedIn && currentPermissions.contains(permissionId);

  bool canAny(Iterable<String> permissionIds) => permissionIds.any(can);

  bool get hasContractorPortal => can('contractor.portal');

  bool get hasAdminAccess => can('admin.users');

  /// يستخدم بوابة المتعهد فقط إن لم يملك أي صلاحية من صلاحيات لوحة الإدارة.
  bool get usesContractorPortal =>
      hasContractorPortal &&
      availableViewTabs.isEmpty &&
      !canAny(['requests.supervise', 'requests.security', 'requests.visitor', 'admin.users']);

  /// يشتق نوع المستخدم النظامي من الدور المختار (للربط مع بوابة المتعهد).
  UserRole userRoleForRoleId(String roleId) {
    final role = roleById(roleId);
    if (role == null) return UserRole.housingSupervisor;
    if (role.permissionIds.contains('admin.users')) return UserRole.admin;
    if (role.permissionIds.contains('contractor.portal')) return UserRole.contractor;
    if (role.permissionIds.contains('requests.visitor') &&
        !role.permissionIds.contains('requests.supervise') &&
        !role.permissionIds.contains('requests.security')) {
      return UserRole.visitorSupervisor;
    }
    if (role.permissionIds.contains('requests.security') &&
        !role.permissionIds.contains('requests.supervise')) {
      return UserRole.securitySupervisor;
    }
    return UserRole.housingSupervisor;
  }

  /// الشاشات الرئيسية المتاحة حسب صلاحيات المستخدم (لترتيب تبويبات الشل).
  List<String> get availableViewTabs {
    final tabs = <String>[];
    if (can('dashboard.view')) tabs.add('dashboard');
    if (can('residents.view')) tabs.add('residents');
    if (can('housing.view')) tabs.add('housing');
    if (can('operations.view')) tabs.add('operations');
    if (can('reports.view')) tabs.add('reports');
    return tabs;
  }

  /// تسجيل دخول عبر الخادم المشترك. يعيد null عند النجاح أو رسالة خطأ.
  Future<String?> loginAsync(String username, String password) async {
    _lastSyncError = null;
    try {
      _api ??= HousingApi(baseUrl: _baseUrl);
      if (!await _api!.checkHealth()) {
        _online = false;
        _lastSyncError = 'تعذّر الاتصال بالخادم على العنوان: $_baseUrl';
        notifyListeners();
        return _lastSyncError;
      }
      _online = true;
      final result = await _api!.login(username, password);
      _api!.token = result['token'] as String?;
      final userJson = (result['user'] as Map).cast<String, dynamic>();
      final user = AppUser.fromJson(userJson);
      currentUser = user;
      _startSyncTimer();
      notifyListeners();
      unawaited(syncNow());
      return null;
    } catch (e) {
      return e is ApiException ? e.message : 'تعذّر تسجيل الدخول: $e';
    }
  }

  void setToken(String? token) {
    _api ??= HousingApi(baseUrl: _baseUrl);
    _api!.token = token;
  }

  void loginAs(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    _api?.token = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    notifyListeners();
  }

  // ---- إدارة المستخدمين ----
  bool usernameTaken(String username, {String? exceptId}) {
    final u = username.trim().toLowerCase();
    return users.any((x) => x.id != exceptId && x.username.toLowerCase() == u);
  }

  void addUser({
    required String name,
    required String username,
    required String password,
    required UserRole role,
    String? roleId,
    String phone = '',
    String? contractorId,
    String contractorName = '',
  }) {
    users.insert(0, AppUser(
      id: 'u${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      username: username.trim(),
      password: password,
      role: role,
      roleId: roleId,
      phone: phone.trim(),
      contractorId: contractorId,
      contractorName: contractorName,
    ));
    notifyListeners();
  }

  void updateUser(AppUser updated) {
    final i = users.indexWhere((u) => u.id == updated.id);
    if (i < 0) return;
    users[i] = updated;
    if (currentUser?.id == updated.id) currentUser = updated;
    notifyListeners();
  }

  void deleteUser(String id) {
    users.removeWhere((u) => u.id == id);
    if (currentUser?.id == id) currentUser = null;
    notifyListeners();
  }

  /// ينشئ مستخدماً ويحفظه في الخادم. يعيد null عند النجاح أو رسالة خطأ.
  Future<String?> createUser({
    required String name,
    required String username,
    required String password,
    required UserRole role,
    required String roleId,
    String phone = '',
    String? contractorId,
    String contractorName = '',
  }) async {
    if (name.trim().isEmpty) return 'يرجى إدخال الاسم';
    if (username.trim().isEmpty) return 'يرجى إدخال اسم المستخدم';
    if (usernameTaken(username)) return 'اسم المستخدم مستخدم مسبقاً';
    if (password.isEmpty) return 'يرجى إدخال كلمة المرور';

    if (_online && _api != null) {
      try {
        final saved = await _api!.saveUser({
          'name': name.trim(),
          'username': username.trim(),
          'password': password,
          'role': role.name,
          'roleId': roleId,
          'phone': phone.trim(),
          'contractorId': contractorId,
          'contractorName': contractorName.trim(),
        });
        users.insert(0, saved);
        notifyListeners();
        return null;
      } catch (e) {
        return e is ApiException ? e.message : 'تعذّر حفظ المستخدم: $e';
      }
    }
    addUser(name: name, username: username, password: password, role: role, roleId: roleId, phone: phone, contractorId: contractorId, contractorName: contractorName);
    return null;
  }

  /// يحدّث مستخدماً ويحفظه في الخادم. يعيد null عند النجاح أو رسالة خطأ.
  Future<String?> saveExistingUser(AppUser updated) async {
    if (updated.name.trim().isEmpty) return 'يرجى إدخال الاسم';
    if (updated.username.trim().isEmpty) return 'يرجى إدخال اسم المستخدم';
    if (usernameTaken(updated.username, exceptId: updated.id)) {
      return 'اسم المستخدم مستخدم مسبقاً';
    }
    if (_online && _api != null) {
      try {
        final saved = await _api!.saveUser({
          'id': updated.id,
          'name': updated.name.trim(),
          'username': updated.username.trim(),
          'password': updated.password,
          'role': updated.role.name,
          'roleId': updated.roleId,
          'phone': updated.phone.trim(),
          'contractorId': updated.contractorId,
          'contractorName': updated.contractorName.trim(),
        });
        updateUser(saved);
        return null;
      } catch (e) {
        return e is ApiException ? e.message : 'تعذّر حفظ المستخدم: $e';
      }
    }
    updateUser(updated);
    return null;
  }

  /// يحذف مستخدماً من الخادم. يعيد null عند النجاح أو رسالة خطأ.
  Future<String?> removeUser(String id) async {
    if (_online && _api != null) {
      try {
        await _api!.deleteUser(id);
      } catch (e) {
        return e is ApiException ? e.message : 'تعذّر حذف المستخدم: $e';
      }
    }
    deleteUser(id);
    return null;
  }

  // ---- إدارة الأدوار ----
  bool roleIdTaken(String id) => roles.any((r) => r.id == id);

  void addRole({required String name, String description = '', Set<String> permissionIds = const <String>{}}) {
    roles.add(AppRole(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      permissionIds: Set<String>.of(permissionIds),
    ));
    notifyListeners();
  }

  void updateRole(AppRole updated) {
    final i = roles.indexWhere((r) => r.id == updated.id);
    if (i < 0) return;
    roles[i] = updated;
    notifyListeners();
  }

  void setRolePermissions(String roleId, Set<String> permissionIds) {
    final i = roles.indexWhere((r) => r.id == roleId);
    if (i < 0) return;
    roles[i] = roles[i].copyWith(permissionIds: Set<String>.of(permissionIds));
    notifyListeners();
  }

  int userCountForRole(String roleId) => users.where((u) => u.effectiveRoleId == roleId).length;

  /// يعيد null عند النجاح أو رسالة خطأ.
  String? deleteRole(String roleId) {
    final role = roleById(roleId);
    if (role == null) return 'الدور غير موجود';
    if (role.isSystem) return 'لا يمكن حذف الأدوار النظامية';
    if (userCountForRole(roleId) > 0) return 'لا يمكن حذف دور مرتبط بمستخدمين';
    roles.removeWhere((r) => r.id == roleId);
    notifyListeners();
    return null;
  }

  // ---- إدارة المتعهدين ----
  int contractorUserCount(String contractorId) => users.where((u) => u.contractorId == contractorId).length;

  /// يعيد null عند النجاح أو رسالة خطأ.
  String? createContractor({
    required String name,
    required String contractorType,
    String phone = '',
    String email = '',
    List<String> buildingIds = const <String>[],
    int bedQuota = 0,
  }) {
    if (name.trim().isEmpty) return 'يرجى إدخال اسم المتعهد/المقاول';
    if (buildingIds.isEmpty) return 'يرجى اختيار مبنى واحد على الأقل';
    contractors.add(Contractor(
      id: 'ctr_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      contractorType: contractorType,
      contactPhone: phone.trim(),
      contactEmail: email.trim(),
      buildingIds: List<String>.of(buildingIds),
      bedQuota: bedQuota,
    ));
    notifyListeners();
    return null;
  }

  void updateContractor(Contractor updated) {
    contractors.removeWhere((c) => c.id == updated.id);
    contractors.add(updated);
    notifyListeners();
  }

  /// يعيد null عند النجاح أو رسالة خطأ.
  String? deleteContractor(String id) {
    if (contractorById(id) == null) return 'المتعهد غير موجود';
    if (workerCountForContractor(id) > 0) return 'لا يمكن حذف متعهد مرتبط بعمال مسكّنين';
    if (contractorUserCount(id) > 0) return 'لا يمكن حذف متعهد مرتبط بمستخدم دخول';
    contractors.removeWhere((c) => c.id == id);
    notifyListeners();
    return null;
  }

  /// ربط ساكن (عامل) بمتعهد أو فصله (contractorId = null).
  void assignResidentToContractor(String residentId, String? contractorId) {
    final i = residents.indexWhere((r) => r.id == residentId);
    if (i < 0) return;
    residents[i] = residents[i].copyWith(contractorId: contractorId, clearContractor: contractorId == null);
    notifyListeners();
  }

  /// ربط مجموعة عمال (بالساكن id) بمتعهد.
  void linkWorkersToContractor(String contractorId, Iterable<String> residentIds) {
    final ids = residentIds.toSet();
    for (var i = 0; i < residents.length; i++) {
      if (ids.contains(residents[i].id)) {
        residents[i] = residents[i].copyWith(contractorId: contractorId);
      }
    }
    notifyListeners();
  }

  /// سكان غير مرتبطين بأي متعهد.
  List<Resident> get unlinkedResidents => residents.where((r) => r.contractorId == null).toList();

  // ---- خيارات القوائم المنسدلة (مشتقة من البيانات لتبقى محدّثة) ----
  static bool _isArabicish(String s) => s.runes.any((c) => c > 0x600);

  List<String> _merged(List<String> curated, Iterable<String> dynamicVals) {
    final set = <String>{...curated};
    for (final v in dynamicVals) {
      final t = v.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// الشركات مع اعتبار المتعهدين والمقاولين شركات أيضاً.
  List<String> get companyOptions {
    final set = <String>{for (final c in contractors) c.name};
    for (final r in residents) {
      final t = r.company.trim();
      if (t.isNotEmpty) set.add(t);
    }
    return set.toList()..sort();
  }

  List<String> get departmentOptions {
    final set = <String>{};
    for (final r in residents) {
      final t = r.department.trim();
      if (t.isNotEmpty) set.add(t);
    }
    return set.toList()..sort();
  }

  static const List<String> _dutyTypeCurated = [
    'من السبت - الخميس',
    'من السبت - الثلاثاء',
    'من الاثنين - الخميس',
    'من الاحد - الخميس',
    'من الأحد - الأربعاء',
    'من الأربعاء - السبت',
    'سبت واحد واربعاء وخميس دوام - اثنين وثلاثاء إجازة',
    'شهر عمل/ شهر راحة',
    'أسبوع عمل/ أسبوع راحة',
    'أسبوعين عمل / أسبوعين راحة',
    '6أسابيع عمل/3أسابيع راحة',
    '6أسابيع عمل/3أسابيع راحة (اداري)',
  ];

  List<String> get dutyTypeOptions =>
      _merged(_dutyTypeCurated, residents.map((r) => r.shift).where(_isArabicish));

  static const List<String> _serviceTypeCurated = ['سكن', 'نقل', 'نقل-سكن', 'أخرى'];

  List<String> get serviceTypeOptions => _merged(_serviceTypeCurated, residents.map((r) => r.serviceType).where(_isArabicish));

  static const List<String> _transportCurated = ['نقل دوري', 'نقل يومي'];

  List<String> get transportTypeOptions => _merged(_transportCurated, residents.map((r) => r.transportType));

  List<String> get genderOptions => const ['ذكر', 'أنثى'];

  // ---- تقارير الشركات والسكنات ----
  /// الساكنون فعلياً: من يتضمّن نوع خدمته كلمة «سكن» (سكن أو نقل-سكن).
  /// من كان نوع خدمته «نقل» أو «أخرى» لا يُعتبر من الساكنين.
  List<Resident> get housingResidents => residents.where((r) => r.isHousingService).toList();
  int get housingResidentCount => housingResidents.length;
  List<Resident> get nonHousingResidents => residents.where((r) => !r.isHousingService).toList();

  int get totalPresent => housingResidents.where((r) => r.attendanceStatus == 'متواجد').length;

  List<AttendanceStat> get companyStats => companyStatsOf(housingResidents);

  List<AttendanceStat> get buildingStats => buildingStatsOf(housingResidents);

  List<AttendanceStat> companyStatsOf(Iterable<Resident> list) =>
      _groupStats(list, (r) => r.company.trim().isEmpty ? 'غير محدد' : r.company.trim());

  List<AttendanceStat> buildingStatsOf(Iterable<Resident> list) =>
      _groupStats(list, (r) => buildingFor(r.buildingId)?.name ?? 'غير مسكن');

  List<AttendanceStat> _groupStats(Iterable<Resident> list, String Function(Resident) keyOf) {
    final map = <String, List<Resident>>{};
    for (final r in list) {
      map.putIfAbsent(keyOf(r), () => []).add(r);
    }
    final rows = map.entries
        .map((e) => AttendanceStat(
              label: e.key,
              total: e.value.length,
              present: e.value.where((r) => r.attendanceStatus == 'متواجد').length,
            ))
        .toList();
    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  // ---- contractors ----
  Contractor? contractorById(String? id) {
    for (final c in contractors) {
      if (c.id == id) return c;
    }
    return null;
  }

  Contractor? get currentContractor => contractorById(currentContractorId);

  List<BuildingUnit> buildingsForContractor(String? contractorId) {
    final c = contractorById(contractorId);
    if (c == null) return const [];
    return buildings.where((b) => c.buildingIds.contains(b.id)).toList();
  }

  List<Resident> workersForContractor(String? contractorId) {
    if (contractorId == null) return const [];
    return residents.where((r) => r.contractorId == contractorId).toList();
  }

  int workerCountForContractor(String? contractorId) => workersForContractor(contractorId).length;

  List<BedUnit> bedsForContractor(String? contractorId) {
    final c = contractorById(contractorId);
    if (c == null) return const [];
    final roomIds = rooms.where((r) => c.buildingIds.contains(r.buildingId)).map((r) => r.id).toSet();
    return beds.where((b) => roomIds.contains(b.roomId)).toList();
  }

  int capacityForContractor(String? contractorId) => contractorById(contractorId)?.bedQuota ?? 0;

  int occupiedForContractor(String? contractorId) => workerCountForContractor(contractorId);

  int freeBedCountForContractor(String? contractorId) {
    final free = capacityForContractor(contractorId) - occupiedForContractor(contractorId);
    return free < 0 ? 0 : free;
  }

  List<BedUnit> freeBedsForContractor(String? contractorId) {
    final used = residents.where((r) => r.isAssigned).map((r) => r.bedId).toSet();
    return bedsForContractor(contractorId).where((b) => !used.contains(b.id)).toList();
  }

  List<ContractorWorker> registeredWorkersForContractor(String? contractorId) {
    return contractorWorkers.where((w) => w.contractorId == contractorId).toList();
  }

  List<ContractorRequest> requestsForContractor(String? contractorId) {
    return contractorRequests.where((r) => r.contractorId == contractorId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ContractorRequest> get pendingContractorRequests =>
      contractorRequests.where((r) => r.isPending).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<ContractorRequest> get housingPendingRequests =>
      contractorRequests.where((r) => r.awaitingHousing).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<ContractorRequest> get securityPendingRequests =>
      contractorRequests.where((r) => r.awaitingSecurity).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<ContractorRequest> get visitorPendingRequests =>
      contractorRequests.where((r) => r.awaitingVisitor).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// ينشئ طلب إضافة/استبعاد ويرسله للخادم المشترك.
  /// يعيد null عند النجاح أو رسالة خطأ.
  Future<String?> submitContractorRequest({
    required String contractorId,
    required String type,
    required String workerName,
    String employeeCode = '',
    String jobTitle = '',
    String reason = '',
    String workerCardNumber = '',
    DateTime? workerBirthDate,
    String workerBirthPlace = '',
  }) async {
    final c = contractorById(contractorId);
    if (c == null) return 'المتعهد غير موجود';
    if (workerName.trim().isEmpty) return 'يرجى إدخال اسم العامل';
    if (type == 'new_worker') {
      if (workerCardNumber.trim().isEmpty) return 'يرجى إدخال رقم البطاقة';
      if (workerBirthDate == null) return 'يرجى تحديد تاريخ الميلاد';
      if (workerBirthPlace.trim().isEmpty) return 'يرجى إدخال مكان الميلاد';
      final now = DateTime.now();
      var age = now.year - workerBirthDate.year;
      if (now.month < workerBirthDate.month ||
          (now.month == workerBirthDate.month && now.day < workerBirthDate.day)) {
        age--;
      }
      if (age < 18) return 'لا يسمح بإضافة موظف أقل من 18 عاماً';
      if (freeBedCountForContractor(contractorId) <= 0) {
        return 'لا يوجد سرير متاح لدى المتعهد (${c.name})';
      }
    }
    if (type == 'remove_worker') {
      final exists = workersForContractor(contractorId)
          .any((r) => r.name == workerName.trim() || (employeeCode.isNotEmpty && r.employeeCode == employeeCode));
      if (!exists) return 'العامل غير موجود ضمن عمالة المتعهد';
    }

    final startStage = type == 'new_worker' ? 'security' : 'housing';

    if (_online && _api != null) {
      try {
        final created = await _api!.submitContractorRequest(
          contractorId: contractorId,
          type: type,
          workerName: workerName,
          employeeCode: employeeCode,
          jobTitle: jobTitle,
          reason: reason,
          workerCardNumber: workerCardNumber,
          workerBirthDate: workerBirthDate,
          workerBirthPlace: workerBirthPlace,
        );
        contractorRequests.insert(0, created);
        notifyListeners();
        return null;
      } catch (e) {
        return e is ApiException ? e.message : 'تعذّر إرسال الطلب: $e';
      }
    }

    // دون اتصال: نحتفظ بالطلب محلياً ونضع علامة انتظار المزامنة.
    final localId = 'CR-local-${DateTime.now().millisecondsSinceEpoch}';
    final local = ContractorRequest(
      id: localId,
      contractorId: contractorId,
      contractorName: c.name,
      requestType: type,
      workerName: workerName.trim(),
      employeeCode: employeeCode.trim(),
      jobTitle: jobTitle.trim(),
      workerCardNumber: workerCardNumber.trim(),
      workerBirthDate: workerBirthDate,
      workerBirthPlace: workerBirthPlace.trim(),
      reason: reason.trim(),
      stage: startStage,
      createdAt: DateTime.now(),
    );
    contractorRequests.insert(0, local);
    _pendingUpload.add(ContractorUpload(
      id: localId,
      contractorId: contractorId,
      type: type,
      workerName: workerName.trim(),
      employeeCode: employeeCode.trim(),
      jobTitle: jobTitle.trim(),
      reason: reason.trim(),
      workerCardNumber: workerCardNumber.trim(),
      workerBirthDate: workerBirthDate,
      workerBirthPlace: workerBirthPlace.trim(),
    ));
    notifyListeners();
    return null;
  }

  /// اعتماد المرحلة الأمنية (مشرف الأمن).
  /// في طلب الإضافة: يبدأ من الأمن → ينتقل لمراقب الزوار.
  /// في طلب الاستبعاد: هو المرحلة الوسطى → ينتقل لمراقب الزوار.
  Future<String?> approveSecurityStage(String requestId, {String approver = '', String notes = ''}) async {
    final index = contractorRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) return 'الطلب غير موجود';
    final req = contractorRequests[index];
    if (!req.awaitingSecurity) return 'الطلب ليس بانتظار مشرف الأمن';
    return _advanceStage(
      index, req,
      approverName: approver.isEmpty ? (currentUser?.name ?? 'مشرف الأمن') : approver,
      notes: notes,
      securityApprover: approver.isEmpty ? (currentUser?.name ?? 'مشرف الأمن') : approver,
    );
  }

  /// اعتماد مراقب الزوار. في طلب الإضافة يدخل كود الموظف إجبارياً.
  /// في طلب الإضافة: المرحلة الوسطى → ينتقل لمراقب السكن للتنفيذ.
  /// في طلب الاستبعاد: المرحلة الأخيرة → ينفّذ الحذف.
  Future<String?> approveVisitorStage(String requestId,
      {String approver = '', String notes = '', String employeeCode = ''}) async {
    final index = contractorRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) return 'الطلب غير موجود';
    var req = contractorRequests[index];
    if (!req.awaitingVisitor) return 'الطلب ليس بانتظار مراقب الزوار';

    if (req.isAdd && employeeCode.trim().isEmpty) {
      return 'يرجى إدخال كود الموظف قبل الاعتماد';
    }
    if (req.isAdd) {
      final now = DateTime.now();
      final bd = req.workerBirthDate;
      if (bd != null) {
        var age = now.year - bd.year;
        if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) age--;
        if (age < 18) return 'لا يسمح بإضافة موظف أقل من 18 عاماً';
      }
    }

    final visitorName = approver.isEmpty ? (currentUser?.name ?? 'مراقب الزوار') : approver;
    if (employeeCode.trim().isNotEmpty) {
      req = req.copyWith(employeeCode: employeeCode.trim());
      contractorRequests[index] = req;
    }
    return _advanceStage(
      index, req,
      approverName: visitorName,
      notes: notes,
      visitorApprover: visitorName,
      employeeCode: employeeCode.trim(),
    );
  }

  /// اعتماد مراقب السكن. في طلب الإضافة: المرحلة الأخيرة → ينفّذ التسكين.
  /// في طلب الاستبعاد: المرحلة الأولى → ينتقل للأمن.
  Future<String?> approveHousingStage(String requestId, {String approver = '', String notes = ''}) async {
    final index = contractorRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) return 'الطلب غير موجود';
    final req = contractorRequests[index];
    if (!req.awaitingHousing) return 'الطلب ليس بانتظار مراقب السكن';
    if (req.isAdd && freeBedCountForContractor(req.contractorId) <= 0) {
      return 'لا يوجد فراغ في السكن التابع للمتعهد';
    }
    return _advanceStage(
      index, req,
      approverName: approver.isEmpty ? (currentUser?.name ?? 'مراقب السكن') : approver,
      notes: notes,
      housingApprover: approver.isEmpty ? (currentUser?.name ?? 'مراقب السكن') : approver,
    );
  }

  /// ينفّذ انتقال المرحلة حسب نوع الطلب، وينفّذ التسكين/الحذف في المرحلة الأخيرة.
  Future<String?> _advanceStage(
    int index,
    ContractorRequest req, {
    required String approverName,
    String notes = '',
    String? housingApprover,
    String? securityApprover,
    String? visitorApprover,
    String employeeCode = '',
  }) async {
    final isExecutionStage = req.isAdd ? req.stage == 'housing' : req.stage == 'visitor';

    if (_online && _api != null) {
      try {
        final updated = await _api!.approveStage(
          requestId: req.id,
          stage: req.stage,
          notes: notes,
          employeeCode: employeeCode,
        );
        contractorRequests[index] = updated;
        notifyListeners();
        if (isExecutionStage) unawaited(refreshFromServer());
        return null;
      } catch (e) {
        return e is ApiException ? e.message : 'تعذّر اعتماد الطلب: $e';
      }
    }

    String? bedId;
    String? resolvedEmployeeCode = employeeCode.trim().isEmpty ? req.employeeCode : employeeCode.trim();
    if (isExecutionStage) {
      if (req.isAdd) {
        final free = freeBedsForContractor(req.contractorId);
        if (free.isEmpty) return 'لا يوجد فراغ متاح للتنفيذ';
        final bed = free.first;
        bedId = bed.id;
        addResident(
          name: req.workerName,
          employeeCode: resolvedEmployeeCode,
          jobTitle: req.jobTitle.isEmpty ? 'عامل متعهد' : req.jobTitle,
          company: req.contractorName,
          department: 'متعهدون ومقاولون',
          shift: 'نهاري',
          rotation: '',
          bedId: bed.id,
          contractorId: req.contractorId,
          cardNumber: req.workerCardNumber,
          birthDate: req.workerBirthDate,
          birthPlace: req.workerBirthPlace,
        );
      } else {
        final names = {req.workerName, if (resolvedEmployeeCode.isNotEmpty) resolvedEmployeeCode};
        residents.removeWhere((r) =>
            r.contractorId == req.contractorId &&
            (names.contains(r.name) || names.contains(r.employeeCode)));
      }
    }

    contractorRequests[index] = req.copyWith(
      stage: req.nextStage,
      bedId: bedId,
      employeeCode: resolvedEmployeeCode.isEmpty ? null : resolvedEmployeeCode,
      housingApprover: housingApprover,
      securityApprover: securityApprover,
      visitorApprover: visitorApprover,
      reviewedAt: DateTime.now(),
      reviewNotes: notes,
    );
    notifyListeners();
    return null;
  }

  /// رفض طلب. يعيد null عند النجاح أو رسالة خطأ.
  Future<String?> rejectContractorRequest(String requestId, {String approver = '', String reviewNotes = ''}) async {
    final index = contractorRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) return 'الطلب غير موجود';
    final req = contractorRequests[index];
    if (req.isDone || req.isRejected) return 'الطلب مغلق مسبقاً';
    if (_online && _api != null) {
      try {
        final updated = await _api!.rejectRequest(requestId, notes: reviewNotes);
        contractorRequests[index] = updated;
        notifyListeners();
        return null;
      } catch (e) {
        return e is ApiException ? e.message : 'تعذّر رفض الطلب: $e';
      }
    }
    contractorRequests[index] = req.copyWith(
      stage: 'rejected',
      reviewedAt: DateTime.now(),
      reviewNotes: reviewNotes,
    );
    notifyListeners();
    return null;
  }

  int get totalBeds => beds.length;
  int get occupiedBeds => residents.where((r) => r.isAssigned).length;
  int get availableBeds => totalBeds - occupiedBeds;
  int get occupancyPercent => totalBeds == 0 ? 0 : ((occupiedBeds / totalBeds) * 100).round();
  int countStatus(String status) => housingResidents.where((r) => r.attendanceStatus == status).length;
  int get assignedResidents => housingResidents.where((r) => r.isAssigned).length;
  int get unassignedResidents => housingResidents.where((r) => !r.isAssigned).length;
  int get onDutyCount => housingResidents.where((r) => r.onDuty).length;
  int get dutyLeaveCount => housingResidents.where((r) => r.dutyStatus == 'إجازة').length;
  int get dutyKnownCount => housingResidents.where((r) => r.dutyStatus.isNotEmpty).length;

  /// سكان نوع خدمتهم تشمل السكن (سكن منفردة أو مجتمعة) وحالتهم الدورية «مداوم».
  List<Resident> get housingServiceOnDuty =>
      residents.where((r) => r.isHousingService && r.onDuty).toList();

  int get housingServiceOnDutyCount => housingServiceOnDuty.length;

  Map<String, int> get housingServiceOnDutyByType {
    final map = <String, int>{};
    for (final r in housingServiceOnDuty) {
      final key = r.serviceTypeLabel;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  /// توزيع سكان «مداوم» حسب نوع الخدمة (مع تجميع «سكن» و«نقل-سكن» تحت وسم السكن).
  Map<String, int> get onDutyByServiceType {
    final map = <String, int>{};
    for (final r in residents) {
      if (!r.onDuty) continue;
      final key = r.serviceTypeLabel;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  List<BedUnit> get freeBeds {
    final used = residents.where((r) => r.isAssigned).map((r) => r.bedId).toSet();
    return beds.where((bed) => !used.contains(bed.id)).toList();
  }

  Resident? residentOnBed(String bedId) {
    for (final resident in residents) {
      if (resident.bedId == bedId) return resident;
    }
    return null;
  }

  BuildingUnit? buildingFor(String? id) {
    for (final building in buildings) {
      if (building.id == id) return building;
    }
    return null;
  }

  RoomUnit? roomFor(String? id) {
    for (final room in rooms) {
      if (room.id == id) return room;
    }
    return null;
  }

  BedUnit? bedFor(String? id) {
    for (final bed in beds) {
      if (bed.id == id) return bed;
    }
    return null;
  }

  String locationFor(Resident resident) {
    final building = buildingFor(resident.buildingId)?.name;
    final room = roomFor(resident.roomId)?.name;
    final bed = bedFor(resident.bedId)?.label;
    if (!resident.isAssigned) return 'غير مسكن';
    return '${building ?? 'سكن'} • ${room ?? ''} • ${bed ?? ''}';
  }

  void addResident({
    required String name,
    required String employeeCode,
    required String jobTitle,
    required String company,
    required String department,
    required String shift,
    required String rotation,
    String serviceType = '',
    String phone = '',
    String gender = '',
    String transportType = '',
    String departureTime = '',
    String cardNumber = '',
    DateTime? birthDate,
    String birthPlace = '',
    String? bedId,
    String? contractorId,
    DateTime? dutyCycleStart,
    int dutyWorkDays = 0,
    int dutyRestDays = 0,
    String baseStatus = 'متواجد',
  }) {
    String? buildingId;
    String? roomId;
    if (bedId != null) {
      final bed = bedFor(bedId);
      roomId = bed?.roomId;
      buildingId = rooms.where((r) => r.id == roomId).firstOrNull?.buildingId;
    }
    residents.insert(0, Resident(
      id: 'u${DateTime.now().microsecondsSinceEpoch}',
      employeeCode: employeeCode.trim(),
      name: name.trim(),
      jobTitle: jobTitle.trim().isEmpty ? 'غير محدد' : jobTitle.trim(),
      company: company.trim().isEmpty ? 'غير محدد' : company.trim(),
      department: department.trim().isEmpty ? 'غير محدد' : department.trim(),
      shift: shift,
      rotation: rotation,
      serviceType: serviceType,
      baseStatus: bedId != null ? 'متواجد' : baseStatus,
      buildingId: buildingId,
      roomId: roomId,
      bedId: bedId,
      checkInDate: DateTime.now(),
      phone: phone.trim(),
      gender: gender,
      transportType: transportType,
      departureTime: departureTime,
      cardNumber: cardNumber.trim(),
      birthDate: birthDate,
      birthPlace: birthPlace.trim(),
      contractorId: contractorId,
      dutyCycleStart: dutyCycleStart,
      dutyWorkDays: dutyWorkDays,
      dutyRestDays: dutyRestDays,
    ));
    notifyListeners();
  }

  bool assignBed(String residentId, String bedId) {
    final bed = bedFor(bedId);
    if (bed == null) return false;
    final occupant = residentOnBed(bedId);
    if (occupant != null && occupant.id != residentId) return false;
    final room = roomFor(bed.roomId);
    final index = residents.indexWhere((r) => r.id == residentId);
    if (index < 0 || room == null) return false;
    residents[index] = residents[index].copyWith(buildingId: room.buildingId, roomId: room.id, bedId: bed.id);
    notifyListeners();
    return true;
  }

  void deleteResident(String residentId) {
    residents.removeWhere((r) => r.id == residentId);
    notifyListeners();
  }

  Resident? residentById(String id) {
    for (final resident in residents) { if (resident.id == id) return resident; }
    return null;
  }

  void scheduleBedRotation({required String bedId, required String outgoingResidentId, required String incomingResidentId, required DateTime scheduledFor}) {
    rotations.insert(0, BedRotation(
      id: 'ROT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      bedId: bedId,
      outgoingResidentId: outgoingResidentId,
      incomingResidentId: incomingResidentId,
      scheduledFor: scheduledFor,
      status: 'مجدول',
    ));
    final incoming = residentById(incomingResidentId);
    if (incoming != null) {
      addRequest(requestType: 'تناوب سرير', resident: incoming, details: 'تناوب مجدول على ${bedFor(bedId)?.label ?? bedId} بتاريخ ${scheduledFor.year}-${scheduledFor.month.toString().padLeft(2, '0')}-${scheduledFor.day.toString().padLeft(2, '0')}');
    }
    notifyListeners();
  }

  bool executeBedRotation(String rotationId) {
    final index = rotations.indexWhere((r) => r.id == rotationId);
    if (index < 0 || rotations[index].status != 'مجدول') return false;
    final rotation = rotations[index];
    final incoming = residentById(rotation.incomingResidentId);
    final outgoing = residentById(rotation.outgoingResidentId);
    if (incoming == null || outgoing == null) return false;
    if (incoming.id != outgoing.id && incoming.bedId != null) unassignBed(incoming.id);
    if (outgoing.bedId == rotation.bedId) unassignBed(outgoing.id);
    final success = assignBed(incoming.id, rotation.bedId);
    if (!success) return false;
    rotations[index] = rotation.copyWith(status: 'منفذ');
    notifyListeners();
    return true;
  }

  void cancelBedRotation(String rotationId) {
    final index = rotations.indexWhere((r) => r.id == rotationId);
    if (index < 0) return;
    rotations[index] = rotations[index].copyWith(status: 'ملغي');
    notifyListeners();
  }

  void unassignBed(String residentId) {
    final index = residents.indexWhere((r) => r.id == residentId);
    if (index < 0) return;
    residents[index] = residents[index].copyWith(clearBed: true);
    notifyListeners();
  }

  void changeAttendance(String residentId, String status) {
    final index = residents.indexWhere((r) => r.id == residentId);
    if (index < 0) return;
    residents[index] = residents[index].copyWith(
      manualStatus: status,
      clearLeave: status != 'إجازة',
      leaveUntil: status == 'إجازة' ? DateTime.now().add(const Duration(days: 7)) : null,
    );
    notifyListeners();
  }

  void addRequest({required String requestType, required Resident resident, required String details}) {
    requests.insert(0, HousingRequest(
      id: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      requestType: requestType,
      residentName: resident.name,
      employeeCode: resident.employeeCode,
      details: details,
      createdAt: DateTime.now(),
      status: 'قيد المراجعة',
    ));
    notifyListeners();
  }

  void processRequest(String requestId, String status) {
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return;
    requests[index] = requests[index].copyWith(status: status);
    notifyListeners();
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

/// طلب متعهد أُنشئ دون اتصال وينتظر الرفع للخادم عند عودة الشبكة.
class ContractorUpload {
  ContractorUpload({
    required this.id,
    required this.contractorId,
    required this.type,
    required this.workerName,
    this.employeeCode = '',
    this.jobTitle = '',
    this.reason = '',
    this.workerCardNumber = '',
    this.workerBirthDate,
    this.workerBirthPlace = '',
  });

  final String id;
  final String contractorId;
  final String type;
  final String workerName;
  final String employeeCode;
  final String jobTitle;
  final String reason;
  final String workerCardNumber;
  final DateTime? workerBirthDate;
  final String workerBirthPlace;
}
