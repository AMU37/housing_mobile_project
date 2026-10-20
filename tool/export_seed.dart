// يصدّر البيانات التجريبية إلى server/seed.json ليستخدمها الخادم كبيانات بداية.
// لا يعتمد على Flutter، لذا يعمل عبر: dart run tool/export_seed.dart
import 'dart:convert';
import 'dart:io';

import 'package:housing_mobile/data/demo_data.dart';

const List<Map<String, dynamic>> _roles = [
  {
    'id': 'r_housing',
    'name': 'مراقب السكن',
    'description': 'يشرف على السكن والسكان ويعتمد طلبات المتعهدين أولياً',
    'isSystem': true,
    'permissionIds': [
      'dashboard.view',
      'residents.view',
      'housing.view',
      'operations.view',
      'reports.view',
      'residents.manage',
      'housing.manage',
      'requests.supervise',
    ],
  },
  {
    'id': 'r_security',
    'name': 'مشرف الأمن',
    'description': 'يعتمد الطلبات أمنياً (المرحلة الأمنية)',
    'isSystem': true,
    'permissionIds': ['operations.view', 'requests.security'],
  },
  {
    'id': 'r_visitor',
    'name': 'مراقب الزوار',
    'description': 'يدقّق بيانات العامل (كود الموظف والعمر) ويعتمد الطلبات',
    'isSystem': true,
    'permissionIds': ['operations.view', 'requests.visitor'],
  },
  {
    'id': 'r_contractor',
    'name': 'متعهد/مقاول',
    'description': 'بوابة المتعهد لإدارة عمالته وتقديم الطلبات',
    'isSystem': true,
    'permissionIds': ['contractor.portal'],
  },
  {
    'id': 'r_admin',
    'name': 'مدير النظام',
    'description': 'كامل الصلاحيات بما فيها إدارة المستخدمين والأدوار',
    'isSystem': true,
    'permissionIds': [
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
    ],
  },
];

void main() {
  final seed = {
    'buildings': demoBuildings.map((e) => {
      'id': e.id,
      'name': e.name,
      'location': e.location,
      'roomIds': e.roomIds,
    }).toList(),
    'rooms': demoRooms.map((e) => {
      'id': e.id,
      'name': e.name,
      'buildingId': e.buildingId,
      'bedIds': e.bedIds,
      'floor': e.floor,
    }).toList(),
    'beds': demoBeds.map((e) => {
      'id': e.id,
      'label': e.label,
      'roomId': e.roomId,
    }).toList(),
    'residents': demoResidents.map((e) => e.toJson()).toList(),
    'requests': demoRequests.map((e) => e.toJson()).toList(),
    'users': demoUsers.map((e) => e.toJson()).toList(),
    'contractors': demoContractors.map((e) => e.toJson()).toList(),
    'contractorWorkers': demoContractorWorkers.map((e) => e.toJson()).toList(),
    'contractorRequests': demoContractorRequests.map((e) => e.toJson()).toList(),
    'roles': _roles,
  };
  final file = File('server/seed.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(seed));
  stdout.writeln('تم إنشاء ${file.path} بنجاح');
}
