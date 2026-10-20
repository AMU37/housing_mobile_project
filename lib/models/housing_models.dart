DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

List<String> _strList(dynamic v) {
  if (v == null) return <String>[];
  return (v as List).map((e) => e.toString()).toList();
}

class Resident {
  const Resident({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.jobTitle,
    required this.company,
    required this.department,
    required this.shift,
    required this.rotation,
    this.serviceType = '',
    this.baseStatus = 'غير مسكن',
    this.manualStatus,
    this.buildingId,
    this.roomId,
    this.bedId,
    this.checkInDate,
    this.leaveUntil,
    this.phone = '',
    this.shiftTable = '',
    this.dutyCycleStart,
    this.dutyWorkDays = 0,
    this.dutyRestDays = 0,
    this.contractorId,
    this.gender = '',
    this.transportType = '',
    this.departureTime = '',
    this.cardNumber = '',
    this.birthDate,
    this.birthPlace = '',
  });

  final String id;
  final String employeeCode;
  final String name;
  final String jobTitle;
  final String company;
  final String department;
  final String shift;
  final String rotation;

  /// نوع الخدمة المسجّل للعامل (مثال: سكن، نقل، نقل-سكن).
  final String serviceType;

  /// الحالة الأساسية القادمة من البصمة/التسكين (لا تتغير تلقائياً).
  final String baseStatus;

  /// تجاوز يدوي يسجله المستخدم من التطبيق (إن وُجد يغلب كل شيء).
  final String? manualStatus;
  final String? buildingId;
  final String? roomId;
  final String? bedId;
  final DateTime? checkInDate;
  final DateTime? leaveUntil;
  final String phone;
  final String shiftTable;
  final DateTime? dutyCycleStart;
  final int dutyWorkDays;
  final int dutyRestDays;

  /// المتعهد/المقاول التابع له العامل (فارغ للموظفين).
  final String? contractorId;

  /// الجنس (ذكر/أنثى).
  final String gender;

  /// تصنيف النقل (نقل دوري، نقل يومي...).
  final String transportType;

  /// وقت المغادرة.
  final String departureTime;

  /// رقم البطاقة (إجباري لعمال المتعهدين والمقاولين).
  final String cardNumber;

  /// تاريخ الميلاد (إجباري لعمال المتعهدين والمقاولين).
  final DateTime? birthDate;

  /// مكان الميلاد (إجباري لعمال المتعهدين والمقاولين).
  final String birthPlace;

  bool get isAssigned => bedId != null && bedId!.isNotEmpty;
  String get dutyCycleLabel => (dutyWorkDays + dutyRestDays) == 0 ? '' : '$dutyWorkDays / $dutyRestDays';

  String get birthDateLabel =>
      birthDate == null ? '' : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}';

  /// حالة نظام الدوام محسوبة لحظياً حسب تاريخ الجهاز.
  String dutyStatusOn(DateTime date) {
    final start = dutyCycleStart;
    final cycle = dutyWorkDays + dutyRestDays;
    if (start == null || cycle <= 0) return '';
    final startDay = DateTime(start.year, start.month, start.day);
    final today = DateTime(date.year, date.month, date.day);
    final pos = today.difference(startDay).inDays % cycle;
    return (pos >= 0 && pos < dutyWorkDays) ? 'مداوم' : 'إجازة';
  }

  String get dutyStatus => dutyStatusOn(DateTime.now());
  bool get onDuty => dutyStatus == 'مداوم';

  /// هل نوع الخدمة يشمل السكن (سكن منفردة أو مجتمعة مثل «نقل-سكن»).
  bool get isHousingService => serviceType.contains('سكن');
  String get serviceTypeLabel => serviceType.isEmpty ? 'غير محدد' : serviceType;

  /// الحالة المعروضة: التجاوز اليدوي، ثم الإجازة الدورية، ثم الحالة الأساسية.
  String get attendanceStatus {
    final manual = manualStatus;
    if (manual != null && manual.isNotEmpty) return manual;
    if (dutyStatus == 'إجازة') return 'إجازة';
    return baseStatus;
  }

  Resident copyWith({
    String? employeeCode,
    String? name,
    String? jobTitle,
    String? company,
    String? department,
    String? shift,
    String? rotation,
    String? serviceType,
    String? baseStatus,
    String? manualStatus,
    String? buildingId,
    String? roomId,
    String? bedId,
    DateTime? checkInDate,
    DateTime? leaveUntil,
    String? phone,
    String? shiftTable,
    DateTime? dutyCycleStart,
    int? dutyWorkDays,
    int? dutyRestDays,
    String? contractorId,
    String? gender,
    String? transportType,
    String? departureTime,
    String? cardNumber,
    DateTime? birthDate,
    String? birthPlace,
    bool clearBed = false,
    bool clearLeave = false,
    bool clearManual = false,
    bool clearContractor = false,
  }) {
    return Resident(
      id: id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      department: department ?? this.department,
      shift: shift ?? this.shift,
      rotation: rotation ?? this.rotation,
      serviceType: serviceType ?? this.serviceType,
      baseStatus: baseStatus ?? this.baseStatus,
      manualStatus: clearManual ? null : (manualStatus ?? this.manualStatus),
      buildingId: clearBed ? null : (buildingId ?? this.buildingId),
      roomId: clearBed ? null : (roomId ?? this.roomId),
      bedId: clearBed ? null : (bedId ?? this.bedId),
      checkInDate: checkInDate ?? this.checkInDate,
      leaveUntil: clearLeave ? null : (leaveUntil ?? this.leaveUntil),
      phone: phone ?? this.phone,
      shiftTable: shiftTable ?? this.shiftTable,
      dutyCycleStart: dutyCycleStart ?? this.dutyCycleStart,
      dutyWorkDays: dutyWorkDays ?? this.dutyWorkDays,
      dutyRestDays: dutyRestDays ?? this.dutyRestDays,
      contractorId: clearContractor ? null : (contractorId ?? this.contractorId),
      gender: gender ?? this.gender,
      transportType: transportType ?? this.transportType,
      departureTime: departureTime ?? this.departureTime,
      cardNumber: cardNumber ?? this.cardNumber,
      birthDate: birthDate ?? this.birthDate,
      birthPlace: birthPlace ?? this.birthPlace,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeCode': employeeCode,
        'name': name,
        'jobTitle': jobTitle,
        'company': company,
        'department': department,
        'shift': shift,
        'rotation': rotation,
        'serviceType': serviceType,
        'baseStatus': baseStatus,
        'manualStatus': manualStatus,
        'buildingId': buildingId,
        'roomId': roomId,
        'bedId': bedId,
        'checkInDate': checkInDate?.toIso8601String(),
        'leaveUntil': leaveUntil?.toIso8601String(),
        'phone': phone,
        'shiftTable': shiftTable,
        'dutyCycleStart': dutyCycleStart?.toIso8601String(),
        'dutyWorkDays': dutyWorkDays,
        'dutyRestDays': dutyRestDays,
        'contractorId': contractorId,
        'gender': gender,
        'transportType': transportType,
        'departureTime': departureTime,
        'cardNumber': cardNumber,
        'birthDate': birthDate?.toIso8601String(),
        'birthPlace': birthPlace,
      };

  factory Resident.fromJson(Map<String, dynamic> j) => Resident(
        id: j['id'] as String,
        employeeCode: (j['employeeCode'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        jobTitle: (j['jobTitle'] ?? '') as String,
        company: (j['company'] ?? '') as String,
        department: (j['department'] ?? '') as String,
        shift: (j['shift'] ?? '') as String,
        rotation: (j['rotation'] ?? '') as String,
        serviceType: (j['serviceType'] ?? '') as String,
        baseStatus: (j['baseStatus'] ?? 'غير مسكن') as String,
        manualStatus: j['manualStatus'] as String?,
        buildingId: j['buildingId'] as String?,
        roomId: j['roomId'] as String?,
        bedId: j['bedId'] as String?,
        checkInDate: _parseDate(j['checkInDate']),
        leaveUntil: _parseDate(j['leaveUntil']),
        phone: (j['phone'] ?? '') as String,
        shiftTable: (j['shiftTable'] ?? '') as String,
        dutyCycleStart: _parseDate(j['dutyCycleStart']),
        dutyWorkDays: (j['dutyWorkDays'] ?? 0) as int,
        dutyRestDays: (j['dutyRestDays'] ?? 0) as int,
        contractorId: j['contractorId'] as String?,
        gender: (j['gender'] ?? '') as String,
        transportType: (j['transportType'] ?? '') as String,
        departureTime: (j['departureTime'] ?? '') as String,
        cardNumber: (j['cardNumber'] ?? '') as String,
        birthDate: _parseDate(j['birthDate']),
        birthPlace: (j['birthPlace'] ?? '') as String,
      );
}

class BuildingUnit {
  const BuildingUnit({required this.id, required this.name, required this.location, required this.roomIds});
  final String id;
  final String name;
  final String location;
  final List<String> roomIds;
}

/// صف تقرير: إجمالي المرتبطين والمتواجدين والنسبة.
class AttendanceStat {
  const AttendanceStat({required this.label, required this.total, required this.present, this.note = ''});
  final String label;
  final int total;
  final int present;
  final String note;
  int get away => total - present;
  double get percent => total == 0 ? 0 : present / total;
  int get percentRounded => (percent * 100).round();
}

/// فلاتر فترات سريعة جاهزة (تُترجم إلى نطاق تاريخ عند الاستخدام).
class QuickPeriod {
  const QuickPeriod(this.id, this.label);
  final String id;
  final String label;
}

const List<QuickPeriod> kQuickPeriods = [
  QuickPeriod('today', 'اليوم'),
  QuickPeriod('yesterday', 'أمس'),
  QuickPeriod('week', 'آخر 7 أيام'),
  QuickPeriod('month', 'آخر 30 يوم'),
  QuickPeriod('thisMonth', 'هذا الشهر'),
  QuickPeriod('all', 'الكل'),
];

class RoomUnit {
  const RoomUnit({required this.id, required this.name, required this.buildingId, required this.bedIds, this.floor = 'الأرضي'});
  final String id;
  final String name;
  final String buildingId;
  final List<String> bedIds;
  final String floor;
}

class BedUnit {
  const BedUnit({required this.id, required this.label, required this.roomId});
  final String id;
  final String label;
  final String roomId;
}

class HousingRequest {
  const HousingRequest({
    required this.id,
    required this.requestType,
    required this.residentName,
    required this.employeeCode,
    required this.details,
    required this.createdAt,
    required this.status,
  });
  final String id;
  final String requestType;
  final String residentName;
  final String employeeCode;
  final String details;
  final DateTime createdAt;
  final String status;

  HousingRequest copyWith({String? status}) => HousingRequest(
        id: id,
        requestType: requestType,
        residentName: residentName,
        employeeCode: employeeCode,
        details: details,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestType': requestType,
        'residentName': residentName,
        'employeeCode': employeeCode,
        'details': details,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };

  factory HousingRequest.fromJson(Map<String, dynamic> j) => HousingRequest(
        id: j['id'] as String,
        requestType: (j['requestType'] ?? '') as String,
        residentName: (j['residentName'] ?? '') as String,
        employeeCode: (j['employeeCode'] ?? '') as String,
        details: (j['details'] ?? '') as String,
        createdAt: _parseDate(j['createdAt']) ?? DateTime(2026, 1, 1),
        status: (j['status'] ?? '') as String,
      );
}

enum UserRole { admin, housingSupervisor, securitySupervisor, visitorSupervisor, contractor }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.housingSupervisor:
        return 'مراقب السكن';
      case UserRole.securitySupervisor:
        return 'مشرف الأمن';
      case UserRole.visitorSupervisor:
        return 'مراقب الزوار';
      case UserRole.contractor:
        return 'متعهد/مقاول';
    }
  }

  String get defaultRoleId {
    switch (this) {
      case UserRole.admin:
        return 'r_admin';
      case UserRole.housingSupervisor:
        return 'r_housing';
      case UserRole.securitySupervisor:
        return 'r_security';
      case UserRole.visitorSupervisor:
        return 'r_visitor';
      case UserRole.contractor:
        return 'r_contractor';
    }
  }
}

/// صلاحية واحدة ضمن كتالوج صلاحيات التطبيق.
class AppPermission {
  const AppPermission(this.id, this.label, this.group);
  final String id;
  final String label;
  final String group;
}

/// كتالوج الصلاحيات الثابت الذي يمكن منحه للأدوار.
const List<AppPermission> appPermissionCatalog = [
  AppPermission('dashboard.view', 'عرض لوحة المعلومات', 'الشاشات'),
  AppPermission('residents.view', 'عرض السكان', 'الشاشات'),
  AppPermission('housing.view', 'عرض السكن والأسرّة', 'الشاشات'),
  AppPermission('operations.view', 'عرض المتابعة', 'الشاشات'),
  AppPermission('reports.view', 'عرض التقارير', 'الشاشات'),
  AppPermission('residents.manage', 'إدارة السكان (إضافة/تعديل)', 'العمليات'),
  AppPermission('housing.manage', 'إدارة السكن والتنقلات', 'العمليات'),
  AppPermission('requests.supervise', 'اعتماد طلبات المتعهدين (مراقب السكن)', 'الاعتماد'),
  AppPermission('requests.security', 'الاعتماد الأمني (مشرف الأمن)', 'الاعتماد'),
  AppPermission('requests.visitor', 'اعتماد مراقب الزوار (كود الموظف والعمر)', 'الاعتماد'),
  AppPermission('contractor.portal', 'بوابة المتعهد/المقاول', 'خاص'),
  AppPermission('admin.users', 'إدارة المستخدمين والأدوار', 'الإدارة'),
];

/// دور يربط مجموعة صلاحيات باسم معروض، ويمكن إنشاؤه وتعديله من شاشة الإدارة.
class AppRole {
  const AppRole({
    required this.id,
    required this.name,
    this.description = '',
    this.isSystem = false,
    this.permissionIds = const <String>{},
  });

  final String id;
  final String name;
  final String description;
  final bool isSystem;
  final Set<String> permissionIds;

  AppRole copyWith({String? name, String? description, Set<String>? permissionIds}) => AppRole(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isSystem: isSystem,
        permissionIds: permissionIds ?? this.permissionIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'isSystem': isSystem,
        'permissionIds': permissionIds.toList(),
      };

  factory AppRole.fromJson(Map<String, dynamic> j) => AppRole(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        isSystem: (j['isSystem'] ?? false) as bool,
        permissionIds: _strList(j['permissionIds']).toSet(),
      );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.role,
    this.roleId,
    this.phone = '',
    this.contractorId,
    this.contractorName = '',
    this.companyName = '',
  });

  final String id;
  final String name;
  final String username;
  final String password;
  final UserRole role;
  final String? roleId;
  final String phone;
  final String? contractorId;
  final String contractorName;
  final String companyName;

  bool get isSupervisor => role == UserRole.housingSupervisor;
  bool get isSecuritySupervisor => role == UserRole.securitySupervisor;
  bool get isVisitorSupervisor => role == UserRole.visitorSupervisor;
  bool get isContractor => role == UserRole.contractor;
  bool get isAdmin => role == UserRole.admin;

  /// معرّف الدور الفعلي، أو الدور الافتراضي المشتق من نوع المستخدم.
  String get effectiveRoleId => (roleId != null && roleId!.isNotEmpty) ? roleId! : role.defaultRoleId;

  String get initial {
    final n = name.trim();
    return n.isEmpty ? '?' : n.substring(0, 1);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'password': password,
        'role': role.name,
        'roleId': roleId,
        'phone': phone,
        'contractorId': contractorId,
        'contractorName': contractorName,
        'companyName': companyName,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) {
    UserRole role = UserRole.housingSupervisor;
    final rn = j['role'] as String?;
    for (final r in UserRole.values) {
      if (r.name == rn) role = r;
    }
    return AppUser(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      username: (j['username'] ?? '') as String,
      password: (j['password'] ?? '') as String,
      role: role,
      roleId: j['roleId'] as String?,
      phone: (j['phone'] ?? '') as String,
      contractorId: j['contractorId'] as String?,
      contractorName: (j['contractorName'] ?? '') as String,
      companyName: (j['companyName'] ?? '') as String,
    );
  }
}

class Contractor {
  const Contractor({
    required this.id,
    required this.name,
    required this.contractorType,
    this.contactPhone = '',
    this.contactEmail = '',
    this.status = 'active',
    this.buildingIds = const <String>[],
    this.bedQuota = 0,
  });

  final String id;
  final String name;
  final String contractorType;
  final String contactPhone;
  final String contactEmail;
  final String status;
  final List<String> buildingIds;

  /// عدد الأسرّة المخصصة للمتعهد ضمن السكن المشترك.
  final int bedQuota;

  String get typeLabel {
    switch (contractorType) {
      case 'cleaning':
        return 'نظافة';
      case 'catering':
        return 'مطعم وتغذية';
      case 'maintenance':
        return 'صيانة عامة';
      case 'electrical':
        return 'كهرباء وإنارة';
      case 'hvac':
        return 'تكييف وتبريد';
      case 'security':
        return 'أمن وحراسة';
      case 'laundry':
        return 'مغسلة';
      case 'general':
        return 'مقاول عام';
      case 'agriculture':
        return 'زراعة';
      case 'labor':
        return 'عمالة';
      case 'services':
        return 'خدمات';
      case 'other':
        return 'أخرى';
      default:
        return contractorType.isEmpty ? 'غير محدد' : contractorType;
    }
  }

  Contractor copyWith({
    String? name,
    String? contractorType,
    String? contactPhone,
    String? contactEmail,
    String? status,
    List<String>? buildingIds,
    int? bedQuota,
  }) => Contractor(
        id: id,
        name: name ?? this.name,
        contractorType: contractorType ?? this.contractorType,
        contactPhone: contactPhone ?? this.contactPhone,
        contactEmail: contactEmail ?? this.contactEmail,
        status: status ?? this.status,
        buildingIds: buildingIds ?? this.buildingIds,
        bedQuota: bedQuota ?? this.bedQuota,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contractorType': contractorType,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'status': status,
        'buildingIds': buildingIds,
        'bedQuota': bedQuota,
      };

  factory Contractor.fromJson(Map<String, dynamic> j) => Contractor(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        contractorType: (j['contractorType'] ?? '') as String,
        contactPhone: (j['contactPhone'] ?? '') as String,
        contactEmail: (j['contactEmail'] ?? '') as String,
        status: (j['status'] ?? 'active') as String,
        buildingIds: _strList(j['buildingIds']),
        bedQuota: (j['bedQuota'] ?? 0) as int,
      );
}

class ContractorWorker {
  const ContractorWorker({
    required this.id,
    required this.contractorId,
    required this.fullName,
    this.jobTitle = '',
    this.employeeCode = '',
    this.status = '',
    this.gateStatus = 'pending',
    this.awarenessStatus = 'pending',
    this.buildingId,
    this.roomId,
    this.bedId,
    this.cardNumber = '',
    this.birthDate,
    this.birthPlace = '',
  });

  final String id;
  final String contractorId;
  final String fullName;
  final String jobTitle;
  final String employeeCode;
  final String status;
  final String gateStatus;
  final String awarenessStatus;
  final String? buildingId;
  final String? roomId;
  final String? bedId;
  final String cardNumber;
  final DateTime? birthDate;
  final String birthPlace;

  bool get isHoused => bedId != null && bedId!.isNotEmpty;

  String get birthDateLabel =>
      birthDate == null ? '' : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}';

  String get statusLabel {
    switch (status) {
      case 'awareness_completed':
        return 'استكمل التوعية';
      case 'security_approved':
        return 'معتمد أمنياً';
      case 'gate_ready':
        return 'جاهز للدخول';
      case 'assigned':
        return 'تم التسكين';
      case 'rejected':
        return 'مرفوض';
      default:
        return status.isEmpty ? 'قيد التسجيل' : status;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contractorId': contractorId,
        'fullName': fullName,
        'jobTitle': jobTitle,
        'employeeCode': employeeCode,
        'status': status,
        'gateStatus': gateStatus,
        'awarenessStatus': awarenessStatus,
        'buildingId': buildingId,
        'roomId': roomId,
        'bedId': bedId,
        'cardNumber': cardNumber,
        'birthDate': birthDate?.toIso8601String(),
        'birthPlace': birthPlace,
      };

  factory ContractorWorker.fromJson(Map<String, dynamic> j) => ContractorWorker(
        id: j['id'] as String,
        contractorId: (j['contractorId'] ?? '') as String,
        fullName: (j['fullName'] ?? '') as String,
        jobTitle: (j['jobTitle'] ?? '') as String,
        employeeCode: (j['employeeCode'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        gateStatus: (j['gateStatus'] ?? 'pending') as String,
        awarenessStatus: (j['awarenessStatus'] ?? 'pending') as String,
        buildingId: j['buildingId'] as String?,
        roomId: j['roomId'] as String?,
        bedId: j['bedId'] as String?,
        cardNumber: (j['cardNumber'] ?? '') as String,
        birthDate: _parseDate(j['birthDate']),
        birthPlace: (j['birthPlace'] ?? '') as String,
      );
}

class ContractorRequest {
  const ContractorRequest({
    required this.id,
    required this.contractorId,
    required this.contractorName,
    required this.requestType,
    required     this.workerName,
    this.employeeCode = '',
    this.jobTitle = '',
    this.workerCardNumber = '',
    this.workerBirthDate,
    this.workerBirthPlace = '',
    this.buildingId,
    this.bedId,
    this.reason = '',
    required this.stage,
    required this.createdAt,
    this.housingApprover = '',
    this.securityApprover = '',
    this.visitorApprover = '',
    this.reviewedAt,
    this.reviewNotes = '',
  });

  final String id;
  final String contractorId;
  final String contractorName;

  /// 'new_worker' للإضافة أو 'remove_worker' للاستبعاد.
  final String requestType;
  final String workerName;
  final String employeeCode;
  final String jobTitle;

  /// رقم بطاقة العامل (إجباري لطلبات الإضافة).
  final String workerCardNumber;

  /// تاريخ ميلاد العامل (إجباري لطلبات الإضافة).
  final DateTime? workerBirthDate;

  /// مكان ميلاد العامل (إجباري لطلبات الإضافة).
  final String workerBirthPlace;
  final String? buildingId;
  final String? bedId;
  final String reason;

  String get workerBirthDateLabel => workerBirthDate == null
      ? ''
      : '${workerBirthDate!.year}-${workerBirthDate!.month.toString().padLeft(2, '0')}-${workerBirthDate!.day.toString().padLeft(2, '0')}';

  /// عمر العامل بالسنوات محسوباً من تاريخ الميلاد.
  int? get workerAge {
    final bd = workerBirthDate;
    if (bd == null) return null;
    final now = DateTime.now();
    var age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  /// مرحلة الطلب:
  /// طلب الإضافة: 'security' ثم 'visitor' ثم 'housing' ثم 'done'.
  /// طلب الاستبعاد: 'housing' ثم 'security' ثم 'visitor' ثم 'done'.
  /// و'rejected' مرفوض من أي مرحلة.
  final String stage;
  final DateTime createdAt;
  final String housingApprover;
  final String securityApprover;

  /// اسم مراقب الزوار الذي اعتمد الطلب.
  final String visitorApprover;
  final DateTime? reviewedAt;
  final String reviewNotes;

  bool get isAdd => requestType == 'new_worker';
  bool get awaitingHousing => stage == 'housing';
  bool get awaitingSecurity => stage == 'security';
  bool get awaitingVisitor => stage == 'visitor';
  bool get isDone => stage == 'done';
  bool get isRejected => stage == 'rejected';
  bool get isPending => awaitingHousing || awaitingSecurity || awaitingVisitor;

  /// المرحلة التالية بعد اعتماد المرحلة الحالية حسب نوع الطلب.
  String get nextStage {
    switch (stage) {
      case 'security':
        return 'visitor';
      case 'visitor':
        return isAdd ? 'housing' : 'done';
      case 'housing':
        return isAdd ? 'done' : 'security';
      default:
        return stage;
    }
  }

  String get typeLabel => isAdd ? 'إضافة عامل' : 'استبعاد عامل';

  String get stageLabel {
    switch (stage) {
      case 'housing':
        return 'بانتظار مراقب السكن';
      case 'security':
        return 'بانتظار مشرف الأمن';
      case 'visitor':
        return 'بانتظار مراقب الزوار';
      case 'done':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      default:
        return stage;
    }
  }

  ContractorRequest copyWith({
    String? stage,
    String? bedId,
    String? buildingId,
    String? employeeCode,
    String? housingApprover,
    String? securityApprover,
    String? visitorApprover,
    DateTime? reviewedAt,
    String? reviewNotes,
  }) {
    return ContractorRequest(
      id: id,
      contractorId: contractorId,
      contractorName: contractorName,
      requestType: requestType,
      workerName: workerName,
      employeeCode: employeeCode ?? this.employeeCode,
      jobTitle: jobTitle,
      workerCardNumber: workerCardNumber,
      workerBirthDate: workerBirthDate,
      workerBirthPlace: workerBirthPlace,
      buildingId: buildingId ?? this.buildingId,
      bedId: bedId ?? this.bedId,
      reason: reason,
      stage: stage ?? this.stage,
      createdAt: createdAt,
      housingApprover: housingApprover ?? this.housingApprover,
      securityApprover: securityApprover ?? this.securityApprover,
      visitorApprover: visitorApprover ?? this.visitorApprover,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contractorId': contractorId,
        'contractorName': contractorName,
        'requestType': requestType,
        'workerName': workerName,
        'employeeCode': employeeCode,
        'jobTitle': jobTitle,
        'workerCardNumber': workerCardNumber,
        'workerBirthDate': workerBirthDate?.toIso8601String(),
        'workerBirthPlace': workerBirthPlace,
        'buildingId': buildingId,
        'bedId': bedId,
        'reason': reason,
        'stage': stage,
        'createdAt': createdAt.toIso8601String(),
        'housingApprover': housingApprover,
        'securityApprover': securityApprover,
        'visitorApprover': visitorApprover,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewNotes': reviewNotes,
      };

  factory ContractorRequest.fromJson(Map<String, dynamic> j) => ContractorRequest(
        id: j['id'] as String,
        contractorId: (j['contractorId'] ?? '') as String,
        contractorName: (j['contractorName'] ?? '') as String,
        requestType: (j['requestType'] ?? '') as String,
        workerName: (j['workerName'] ?? '') as String,
        employeeCode: (j['employeeCode'] ?? '') as String,
        jobTitle: (j['jobTitle'] ?? '') as String,
        workerCardNumber: (j['workerCardNumber'] ?? '') as String,
        workerBirthDate: _parseDate(j['workerBirthDate']),
        workerBirthPlace: (j['workerBirthPlace'] ?? '') as String,
        buildingId: j['buildingId'] as String?,
        bedId: j['bedId'] as String?,
        reason: (j['reason'] ?? '') as String,
        stage: (j['stage'] ?? 'security') as String,
        createdAt: _parseDate(j['createdAt']) ?? DateTime(2026, 1, 1),
        housingApprover: (j['housingApprover'] ?? '') as String,
        securityApprover: (j['securityApprover'] ?? '') as String,
        visitorApprover: (j['visitorApprover'] ?? '') as String,
        reviewedAt: _parseDate(j['reviewedAt']),
        reviewNotes: (j['reviewNotes'] ?? '') as String,
      );
}

class BedRotation {
  const BedRotation({
    required this.id,
    required this.bedId,
    required this.outgoingResidentId,
    required this.incomingResidentId,
    required this.scheduledFor,
    required this.status,
  });
  final String id;
  final String bedId;
  final String outgoingResidentId;
  final String incomingResidentId;
  final DateTime scheduledFor;
  final String status;

  BedRotation copyWith({String? status}) => BedRotation(
    id: id,
    bedId: bedId,
    outgoingResidentId: outgoingResidentId,
    incomingResidentId: incomingResidentId,
    scheduledFor: scheduledFor,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bedId': bedId,
        'outgoingResidentId': outgoingResidentId,
        'incomingResidentId': incomingResidentId,
        'scheduledFor': scheduledFor.toIso8601String(),
        'status': status,
      };

  factory BedRotation.fromJson(Map<String, dynamic> j) => BedRotation(
        id: j['id'] as String,
        bedId: (j['bedId'] ?? '') as String,
        outgoingResidentId: (j['outgoingResidentId'] ?? '') as String,
        incomingResidentId: (j['incomingResidentId'] ?? '') as String,
        scheduledFor: _parseDate(j['scheduledFor']) ?? DateTime(2026, 1, 1),
        status: (j['status'] ?? '') as String,
      );
}
