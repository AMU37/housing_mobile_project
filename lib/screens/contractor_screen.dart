import 'package:flutter/material.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';

class ContractorScreen extends StatelessWidget {
  const ContractorScreen({super.key, required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    final user = store.currentUser;
    final contractor = store.currentContractor;
    if (user == null || contractor == null) {
      return const Center(child: Text('لا يوجد متعهد مرتبط بالحساب'));
    }
    final capacity = store.capacityForContractor(contractor.id);
    final occupied = store.occupiedForContractor(contractor.id);
    final free = store.freeBedCountForContractor(contractor.id);
    final workers = store.workersForContractor(contractor.id);
    final registered = store.registeredWorkersForContractor(contractor.id);
    final requests = store.requestsForContractor(contractor.id);
    final buildingNames = store.buildingsForContractor(contractor.id).map((b) => b.name).join(' • ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(radius: 22, backgroundColor: navy, child: Text(user.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(contractor.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 2),
                  Text('${contractor.typeLabel}${buildingNames.isEmpty ? '' : ' • $buildingNames'}', style: const TextStyle(fontSize: 11, color: muted)),
                ])),
                StatusPill(contractor.status == 'active' ? 'نشط' : contractor.status),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _miniMetric('السعة', '$capacity', Icons.bed_rounded, navy),
                const SizedBox(width: 10),
                _miniMetric('المشغول', '$occupied', Icons.person_rounded, const Color(0xFF2673B8)),
                const SizedBox(width: 10),
                _miniMetric('المتاح', '$free', Icons.check_circle_rounded, free > 0 ? const Color(0xFF16846B) : const Color(0xFFC2414B)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: PrimaryAction(
                  label: 'طلب إضافة عامل',
                  icon: Icons.person_add_alt_1_rounded,
                  compact: true,
                  onPressed: () {
                    if (free <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد فراغ في السكن التابع للمتعهد'), backgroundColor: Color(0xFFC2414B)));
                      return;
                    }
                    _openAddSheet(context, store, contractor, free);
                  },
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: workers.isEmpty ? null : () => _openRemoveSheet(context, store, contractor, workers),
                  icon: const Icon(Icons.person_remove_alt_1_rounded, size: 17),
                  label: const Text('طلب استبعاد عامل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC2414B), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), side: const BorderSide(color: Color(0xFFE7B7BB))),
                )),
              ]),
              if (free <= 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: const Color(0xFFC2414B).withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFC2414B)),
                    SizedBox(width: 8),
                    Expanded(child: Text('السكن التابع للمتعهد ممتلئ — لا يمكن تقديم طلب إضافة حتى يتوفر فراغ.', style: TextStyle(fontSize: 11, color: Color(0xFFC2414B), fontWeight: FontWeight.w700))),
                  ]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle('عمالتي', subtitle: '${workers.length} عامل في السكن التابع للمتعهد'),
        if (workers.isEmpty)
          const AppCard(child: EmptyState(title: 'لا يوجد عمال', subtitle: 'لم يتم تسكين أي عامل ضمن سكن المتعهد بعد', icon: Icons.people_outline_rounded))
        else
          ...workers.map((r) => _workerTile(context, store, r)),
        if (registered.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionTitle('عمالة قيد التسجيل', subtitle: '${registered.length} عامل بانتظار استكمال الإجراءات'),
          ...registered.map((w) => _registeredTile(w)),
        ],
        const SizedBox(height: 18),
        SectionTitle('طلباتي', subtitle: store.hasPendingUploads ? '${requests.length} طلب • بعض الطلبات بانتظار المزامنة' : '${requests.length} طلب'),
        if (requests.isEmpty)
          const AppCard(child: EmptyState(title: 'لا توجد طلبات', subtitle: 'يمكنك تقديم طلب إضافة أو استبعاد عامل', icon: Icons.assignment_outlined))
        else
          ...requests.map((r) => _requestTile(context, r)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _miniMetric(String title, String value, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(.06), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
        Text(title, style: const TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _workerTile(BuildContext context, HousingStore store, Resident r) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(children: [
        CircleAvatar(radius: 19, backgroundColor: const Color(0xFF2673B8).withOpacity(.12), child: Text(r.name.isEmpty ? '?' : r.name.substring(0, 1), style: const TextStyle(color: Color(0xFF2673B8), fontWeight: FontWeight.w900))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: navy)),
          const SizedBox(height: 2),
          Text('${r.jobTitle}${r.employeeCode.isEmpty ? '' : ' • ${r.employeeCode}'}', style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 2),
          Text(store.locationFor(r), style: const TextStyle(fontSize: 10, color: muted)),
          if (r.cardNumber.isNotEmpty || r.birthDate != null || r.birthPlace.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('بطاقة: ${r.cardNumber.isEmpty ? '—' : r.cardNumber} • ميلاد: ${r.birthDateLabel.isEmpty ? '—' : r.birthDateLabel} • ${r.birthPlace.isEmpty ? '—' : r.birthPlace}', style: const TextStyle(fontSize: 10, color: muted)),
          ],
        ])),
        StatusPill(r.attendanceStatus),
      ]),
    ),
  );

  Widget _registeredTile(ContractorWorker w) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(children: [
        const CircleAvatar(radius: 19, backgroundColor: Color(0xFFF3F6FA), child: Icon(Icons.badge_outlined, color: muted, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(w.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: navy)),
          const SizedBox(height: 2),
          Text(w.employeeCode.isEmpty ? 'بدون كود' : w.employeeCode, style: const TextStyle(fontSize: 11, color: muted)),
          if (w.cardNumber.isNotEmpty || w.birthDate != null || w.birthPlace.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('بطاقة: ${w.cardNumber.isEmpty ? '—' : w.cardNumber} • ميلاد: ${w.birthDateLabel.isEmpty ? '—' : w.birthDateLabel} • ${w.birthPlace.isEmpty ? '—' : w.birthPlace}', style: const TextStyle(fontSize: 10, color: muted)),
          ],
        ])),
        StatusPill(w.statusLabel),
      ]),
    ),
  );
}

Widget _requestTile(BuildContext context, ContractorRequest r) {
  final color = r.isRejected ? const Color(0xFFC2414B) : (r.isDone ? const Color(0xFF16846B) : const Color(0xFF9A6700));
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(11)), child: Icon(r.isAdd ? Icons.person_add_alt_1_rounded : Icons.person_remove_alt_1_rounded, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.typeLabel} — ${r.workerName.isEmpty ? 'بدون اسم' : r.workerName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: navy)),
            Text(_dateLabel(r.createdAt), style: const TextStyle(fontSize: 10, color: muted)),
          ])),
          StatusPill(r.stageLabel),
        ]),
        if (r.reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('السبب: ${r.reason}', style: const TextStyle(fontSize: 11, color: muted)),
        ],
        if (r.reviewNotes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('ملاحظة: ${r.reviewNotes}', style: const TextStyle(fontSize: 11, color: Color(0xFF16846B))),
        ],
      ]),
    ),
  );
}

String _dateLabel(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void _openAddSheet(BuildContext context, HousingStore store, Contractor contractor, int free) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _AddWorkerSheet(store: store, contractor: contractor, free: free),
  );
}

void _openRemoveSheet(BuildContext context, HousingStore store, Contractor contractor, List<Resident> workers) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _RemoveWorkerSheet(store: store, contractor: contractor, workers: workers),
  );
}

class _AddWorkerSheet extends StatefulWidget {
  const _AddWorkerSheet({required this.store, required this.contractor, required this.free});
  final HousingStore store;
  final Contractor contractor;
  final int free;
  @override
  State<_AddWorkerSheet> createState() => _AddWorkerSheetState();
}

class _AddWorkerSheetState extends State<_AddWorkerSheet> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _job = TextEditingController();
  final _reason = TextEditingController();
  final _card = TextEditingController();
  final _birthPlace = TextEditingController();
  DateTime? _birthDate;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _job.dispose();
    _reason.dispose();
    _card.dispose();
    _birthPlace.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'تاريخ الميلاد',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    final err = await widget.store.submitContractorRequest(
      contractorId: widget.contractor.id,
      type: 'new_worker',
      workerName: _name.text,
      employeeCode: _code.text,
      jobTitle: _job.text,
      reason: _reason.text,
      workerCardNumber: _card.text,
      workerBirthDate: _birthDate,
      workerBirthPlace: _birthPlace.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الإضافة إلى مراقب السكن'), backgroundColor: Color(0xFF16846B)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('طلب إضافة عامل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 4),
          Text('سكن ${widget.contractor.name} • المتاح: ${widget.free} سرير', style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم العامل *')),
          const SizedBox(height: 10),
          TextField(controller: _card, decoration: const InputDecoration(labelText: 'رقم البطاقة *', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickBirthDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'تاريخ الميلاد *', prefixIcon: Icon(Icons.cake_outlined)),
              child: Text(_birthDate == null ? 'اختر التاريخ' : _fmtDate(_birthDate!), style: TextStyle(fontSize: 14, color: _birthDate == null ? muted : navy)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _birthPlace, decoration: const InputDecoration(labelText: 'مكان الميلاد *', prefixIcon: Icon(Icons.place_outlined))),
          const SizedBox(height: 10),
          TextField(controller: _job, decoration: const InputDecoration(labelText: 'المسمى الوظيفي')),
          const SizedBox(height: 10),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'كود الموظف (اختياري)')),
          const SizedBox(height: 10),
          TextField(controller: _reason, maxLines: 2, decoration: const InputDecoration(labelText: 'سبب الإضافة')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFC2414B), fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          PrimaryAction(label: 'إرسال الطلب', icon: Icons.send_rounded, onPressed: _submit),
        ]),
      ),
    );
  }
}

class _RemoveWorkerSheet extends StatefulWidget {
  const _RemoveWorkerSheet({required this.store, required this.contractor, required this.workers});
  final HousingStore store;
  final Contractor contractor;
  final List<Resident> workers;
  @override
  State<_RemoveWorkerSheet> createState() => _RemoveWorkerSheetState();
}

class _RemoveWorkerSheetState extends State<_RemoveWorkerSheet> {
  Resident? _selected;
  final _reason = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final worker = _selected;
    if (worker == null) {
      setState(() => _attempted = true);
      return;
    }
    await widget.store.submitContractorRequest(
      contractorId: widget.contractor.id,
      type: 'remove_worker',
      workerName: worker.name,
      employeeCode: worker.employeeCode,
      jobTitle: worker.jobTitle,
      reason: _reason.text,
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الاستبعاد إلى مراقب السكن'), backgroundColor: Color(0xFF16846B)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('طلب استبعاد عامل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 12),
        DropdownButtonFormField<Resident>(
          value: _selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'اختر العامل *'),
          items: widget.workers.map((w) => DropdownMenuItem(value: w, child: Text(w.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _selected = v),
        ),
        const SizedBox(height: 10),
        TextField(controller: _reason, maxLines: 2, decoration: const InputDecoration(labelText: 'سبب الاستبعاد')),
        if (_attempted && _selected == null) ...[
          const SizedBox(height: 10),
          const Text('يرجى اختيار العامل', style: TextStyle(color: Color(0xFFC2414B), fontSize: 12, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 16),
        PrimaryAction(label: 'إرسال الطلب', icon: Icons.send_rounded, onPressed: _submit),
      ]),
    );
  }
}
