import 'package:flutter/material.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key, required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
        child: const TabBar(
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(color: teal, borderRadius: BorderRadius.all(Radius.circular(12))),
          labelColor: Colors.white,
          unselectedLabelColor: muted,
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          tabs: [Tab(text: 'الحضور والإجازات', icon: Icon(Icons.fact_check_outlined, size: 18)), Tab(text: 'الطلبات والموافقات', icon: Icon(Icons.assignment_outlined, size: 18))],
        ),
      )),
      Expanded(child: TabBarView(children: [_AttendanceTab(store: store), _RequestsTab(store: store)])),
    ]),
  );
}

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.store});
  final HousingStore store;
  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  String filter = 'الكل';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final residents = widget.store.housingResidents.where((r) => filter == 'الكل' || r.attendanceStatus == filter).toList();
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('متابعة حالة الساكنين', subtitle: 'تحديث حالة التواجد والإجازات والتناوب'),
          Wrap(spacing: 7, children: [for (final value in ['الكل', 'متواجد', 'خارج السكن', 'إجازة', 'غائب']) ChoiceChip(
            label: Text(value), selected: filter == value, onSelected: (_) => setState(() => filter = value),
            selectedColor: teal.withOpacity(.13), labelStyle: TextStyle(fontSize: 10, color: filter == value ? teal : muted, fontWeight: FontWeight.w700), side: BorderSide(color: filter == value ? teal.withOpacity(.3) : line),
          )]),
        ])),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 2, 16, 22), itemCount: residents.length, itemBuilder: (context, index) => _AttendanceCard(store: widget.store, resident: residents[index]))),
      ]);
    },
  );
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.store, required this.resident});
  final HousingStore store;
  final Resident resident;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(12),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: teal.withOpacity(.09), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.person_pin_circle_outlined, color: teal)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(resident.name, style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 3),
        Text('${resident.employeeCode} • ${resident.shiftTable.isNotEmpty ? resident.shiftTable : resident.shift}${resident.rotation.isNotEmpty ? ' • ${resident.rotation}' : ''}', style: const TextStyle(color: muted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 5),
        Text(store.locationFor(resident), style: const TextStyle(color: navy, fontSize: 10)),
        if (resident.dutyStatus.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('نظام الدوام: ${resident.dutyStatus}${resident.dutyCycleLabel.isNotEmpty ? ' (${resident.dutyCycleLabel} يوم)' : ''}', style: TextStyle(color: resident.onDuty ? teal : const Color(0xFF9A6700), fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ])),
      PopupMenuButton<String>(
        tooltip: 'تحديث الحالة',
        icon: const Icon(Icons.edit_note_rounded, color: muted),
        onSelected: (value) {
          store.changeAttendance(resident.id, value);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديث حالة ${resident.name} إلى $value')));
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'متواجد', child: Text('متواجد بالسكن')),
          PopupMenuItem(value: 'خارج السكن', child: Text('خارج السكن / في الدوام')),
          PopupMenuItem(value: 'إجازة', child: Text('في إجازة')),
          PopupMenuItem(value: 'غائب', child: Text('غائب')),
        ],
      ),
      StatusPill(resident.attendanceStatus),
    ]),
  );
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.store});
  final HousingStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
        const Expanded(child: SectionTitle('طلبات السكن', subtitle: 'متابعة دورة الطلب من التقديم حتى الإغلاق')),
        PrimaryAction(label: 'طلب جديد', icon: Icons.add_rounded, compact: true, onPressed: () => _showNewRequest(context)),
      ])),
      Expanded(child: store.requests.isEmpty
        ? const EmptyState(title: 'لا توجد طلبات', subtitle: 'يمكنك إنشاء طلب جديد للساكنين.')
        : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 22), itemCount: store.requests.length, itemBuilder: (context, index) => _RequestCard(store: store, request: store.requests[index]))),
    ]),
  );

  Future<void> _showNewRequest(BuildContext context) async {
    if (store.housingResidents.isEmpty) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _NewRequestSheet(store: store));
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.store, required this.request});
  final HousingStore store;
  final HousingRequest request;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 39, height: 39, decoration: BoxDecoration(color: navy.withOpacity(.07), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.assignment_outlined, color: navy)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(request.requestType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 2), Text('${request.id} • ${request.employeeCode}', style: const TextStyle(fontSize: 10, color: muted))]),),
        StatusPill(request.status),
      ]),
      const SizedBox(height: 10),
      Text(request.residentName, style: const TextStyle(color: navy, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 4),
      Text(request.details, style: const TextStyle(color: muted, fontSize: 11)),
      if (request.status == 'قيد المراجعة') ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => store.processRequest(request.id, 'مرفوض'), icon: const Icon(Icons.close_rounded, size: 17), label: const Text('رفض'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC2414B)))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(onPressed: () => store.processRequest(request.id, 'معتمد'), icon: const Icon(Icons.check_rounded, size: 17), label: const Text('اعتماد'), style: FilledButton.styleFrom(backgroundColor: teal))),
        ]),
      ],
    ]),
  );
}

class _NewRequestSheet extends StatefulWidget {
  const _NewRequestSheet({required this.store});
  final HousingStore store;
  @override
  State<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<_NewRequestSheet> {
  final formKey = GlobalKey<FormState>();
  final details = TextEditingController();
  late String residentId = widget.store.housingResidents.first.id;
  String type = 'تسكين جديد';
  @override
  void dispose() { details.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 24),
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: SafeArea(child: Form(key: formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('إنشاء طلب سكن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: navy)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: residentId, isExpanded: true, decoration: const InputDecoration(labelText: 'الموظف'), items: widget.store.housingResidents.map((r) => DropdownMenuItem(value: r.id, child: Text('${r.name} • ${r.employeeCode}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) setState(() => residentId = v); }),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'نوع الطلب'), items: ['تسكين جديد', 'نقل سرير', 'إخلاء سكن', 'صيانة غرفة', 'تمديد سكن', 'طلب زيارة'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) setState(() => type = v); }),
      const SizedBox(height: 10),
      TextFormField(controller: details, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'تفاصيل الطلب'), validator: (v) => v == null || v.trim().isEmpty ? 'اكتب تفاصيل مختصرة للطلب' : null),
      const SizedBox(height: 18),
      PrimaryAction(label: 'إرسال الطلب', icon: Icons.send_rounded, onPressed: () {
        if (!formKey.currentState!.validate()) return;
        final resident = widget.store.housingResidents.firstWhere((r) => r.id == residentId);
        widget.store.addRequest(requestType: type, resident: resident, details: details.text.trim());
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('تم إنشاء الطلب وهو الآن قيد المراجعة.')));
      }),
    ])))),
  );
}
