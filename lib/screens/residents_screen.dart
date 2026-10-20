import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';
import '../utils/csv_export.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key, required this.store});
  final HousingStore store;
  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  final TextEditingController searchController = TextEditingController();
  String selectedFilter = 'الكل';
  bool onlyResidents = true;
  String? fCompany;
  String? fDepartment;
  String? fService;
  String? fDuty;
  String? fTransport;
  String? fGender;

  int get activeFilterCount =>
      [fCompany, fDepartment, fService, fDuty, fTransport, fGender].where((e) => e != null).length;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Resident> _applyFilters() {
    final query = searchController.text.trim().toLowerCase();
    return widget.store.residents.where((resident) {
      if (onlyResidents && !resident.isHousingService) return false;
      final matchesQuery = query.isEmpty ||
          '${resident.name} ${resident.employeeCode} ${resident.company} ${resident.department} ${resident.jobTitle}'.toLowerCase().contains(query);
      final matchesFilter = switch (selectedFilter) {
        'متواجد' => resident.attendanceStatus == 'متواجد',
        'إجازة' => resident.attendanceStatus == 'إجازة',
        'غير مسكن' => !resident.isAssigned,
        _ => true,
      };
      final matchesAdvanced = (fCompany == null || resident.company == fCompany) &&
          (fDepartment == null || resident.department == fDepartment) &&
          (fService == null || resident.serviceType == fService) &&
          (fDuty == null || resident.shift == fDuty) &&
          (fTransport == null || resident.transportType == fTransport) &&
          (fGender == null || resident.gender == fGender);
      return matchesQuery && matchesFilter && matchesAdvanced;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final filtered = _applyFilters();
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(children: [
            Row(children: [
              const Expanded(child: SectionTitle('ملف الساكنين', subtitle: 'بيانات الموظفين والتسكين والدوام')),
              _iconButton(Icons.file_download_outlined, 'تصدير', () => _export(filtered)),
              const SizedBox(width: 8),
              PrimaryAction(label: 'إضافة', icon: Icons.person_add_alt_1_rounded, compact: true, onPressed: () => _showAddResident(context)),
            ]),
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث بالاسم أو الرقم الوظيفي أو الشركة'),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              Padding(padding: const EdgeInsets.only(left: 7), child: FilterChip(
                avatar: Icon(onlyResidents ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: onlyResidents ? teal : muted),
                label: const Text('الساكنون فقط'),
                selected: onlyResidents,
                onSelected: (v) => setState(() => onlyResidents = v),
                selectedColor: teal.withOpacity(.14), labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: onlyResidents ? teal : muted),
                side: BorderSide(color: onlyResidents ? teal.withOpacity(.3) : line),
              )),
              for (final filter in ['الكل', 'متواجد', 'إجازة', 'غير مسكن'])
                Padding(padding: const EdgeInsets.only(left: 7), child: ChoiceChip(
                  label: Text(filter), selected: selectedFilter == filter,
                  onSelected: (_) => setState(() => selectedFilter = filter),
                  selectedColor: teal.withOpacity(.14), labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selectedFilter == filter ? teal : muted),
                  side: BorderSide(color: selectedFilter == filter ? teal.withOpacity(.3) : line),
                )),
              Padding(padding: const EdgeInsets.only(left: 7), child: ActionChip(
                avatar: Icon(Icons.tune_rounded, size: 16, color: activeFilterCount > 0 ? teal : muted),
                label: Text(activeFilterCount > 0 ? 'فلاتر متقدمة ($activeFilterCount)' : 'فلاتر متقدمة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: activeFilterCount > 0 ? teal : muted)),
                backgroundColor: activeFilterCount > 0 ? teal.withOpacity(.12) : canvas,
                side: BorderSide(color: activeFilterCount > 0 ? teal.withOpacity(.3) : line),
                onPressed: () => _showAdvancedFilters(context),
              )),
            ])),
            if (activeFilterCount > 0) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 6, children: [
              if (fCompany != null) _activeChip('الشركة: $fCompany', () => setState(() => fCompany = null)),
              if (fDepartment != null) _activeChip('الإدارة: $fDepartment', () => setState(() => fDepartment = null)),
              if (fService != null) _activeChip('الخدمة: $fService', () => setState(() => fService = null)),
              if (fDuty != null) _activeChip('الدوام: $fDuty', () => setState(() => fDuty = null)),
              if (fTransport != null) _activeChip('النقل: $fTransport', () => setState(() => fTransport = null)),
              if (fGender != null) _activeChip('الجنس: $fGender', () => setState(() => fGender = null)),
            ]))),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: Text('النتائج: ${filtered.length} من ${onlyResidents ? widget.store.housingResidentCount : widget.store.residents.length}', style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700))),
          ]),
        ),
        Expanded(child: filtered.isEmpty
          ? const EmptyState(title: 'لا توجد نتائج', subtitle: 'جرّب تغيير البحث أو الفلتر.', icon: Icons.person_search_outlined)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _ResidentCard(store: widget.store, resident: filtered[index], onEdit: () => _showResidentActions(context, filtered[index])),
            )),
      ]);
    },
  );

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
    message: tooltip,
    child: Material(
      color: canvas,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 20, color: teal)),
      ),
    ),
  );

  Widget _activeChip(String label, VoidCallback onRemove) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: teal.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: teal, fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      InkWell(onTap: onRemove, child: const Icon(Icons.close_rounded, size: 14, color: teal)),
    ]),
  );

  Future<void> _showAdvancedFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheet) {
        Widget dd(String label, String? value, List<String> options, ValueChanged<String?> onChanged) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              DropdownMenuItem(value: null, child: Text('الكل', style: TextStyle(color: muted))),
              ...options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) { onChanged(v); setSheet(() {}); setState(() {}); },
          ),
        );
        return SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('فلاتر متقدمة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 4),
            Text('${widget.store.housingResidentCount} ساكن إجمالاً', style: const TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 16),
            dd('الشركة / المتعهد', fCompany, widget.store.companyOptions, (v) => fCompany = v),
            dd('الإدارة / القسم', fDepartment, widget.store.departmentOptions, (v) => fDepartment = v),
            dd('نوع الخدمة', fService, widget.store.serviceTypeOptions, (v) => fService = v),
            dd('نوع الدوام', fDuty, widget.store.dutyTypeOptions, (v) => fDuty = v),
            dd('تصنيف النقل', fTransport, widget.store.transportTypeOptions, (v) => fTransport = v),
            dd('الجنس', fGender, widget.store.genderOptions, (v) => fGender = v),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () { setState(() { fCompany = null; fDepartment = null; fService = null; fDuty = null; fTransport = null; fGender = null; }); Navigator.pop(sheetContext); }, icon: const Icon(Icons.clear_all_rounded, size: 18), label: const Text('مسح الكل'), style: OutlinedButton.styleFrom(foregroundColor: muted, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))))),
              const SizedBox(width: 10),
              Expanded(child: PrimaryAction(label: 'تطبيق', icon: Icons.check_rounded, onPressed: () => Navigator.pop(sheetContext))),
            ]),
          ])),
        ));
      }),
    );
  }

  Future<void> _export(List<Resident> rows) async {
    final header = ['الرقم الوظيفي', 'الاسم', 'المسمى الوظيفي', 'الشركة', 'الإدارة', 'نوع الخدمة', 'نوع الدوام', 'تصنيف النقل', 'الجنس', 'الحالة', 'حالة الدوام', 'الموقع'];
    final data = rows.map((r) => [
      r.employeeCode, r.name, r.jobTitle, r.company, r.department, r.serviceType,
      r.shift, r.transportType, r.gender, r.attendanceStatus, r.dutyStatus, widget.store.locationFor(r),
    ]);
    final csv = buildCsv(header, data);
    await copyCsv(context, csv, 'سكان السكن (${rows.length})');
  }

  Future<void> _showAddResident(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddResidentSheet(store: widget.store),
    );
  }

  Future<void> _showResidentActions(BuildContext context, Resident resident) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(resident.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy)),
          Text('${resident.employeeCode} • ${widget.store.locationFor(resident)}', style: const TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 14),
          const Text('تغيير الحالة', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final status in ['متواجد', 'خارج السكن', 'إجازة', 'غائب'])
              OutlinedButton(onPressed: () { widget.store.changeAttendance(resident.id, status); Navigator.pop(sheetContext); }, child: Text(status)),
          ]),
          const SizedBox(height: 8),
          if (resident.isAssigned)
            ListTile(leading: const Icon(Icons.logout_rounded, color: Color(0xFFC2414B)), title: const Text('إخلاء السرير'), contentPadding: EdgeInsets.zero, onTap: () { widget.store.unassignBed(resident.id); Navigator.pop(sheetContext); }),
          ListTile(leading: const Icon(Icons.swap_horiz_rounded, color: teal), title: const Text('نقل إلى سرير آخر'), contentPadding: EdgeInsets.zero, onTap: () async { Navigator.pop(sheetContext); await _showTransfer(context, resident); }),
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFC2414B)), title: const Text('حذف الساكن من القائمة', style: TextStyle(color: Color(0xFFC2414B))), contentPadding: EdgeInsets.zero, onTap: () async {
            Navigator.pop(sheetContext);
            final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
              title: const Text('تأكيد حذف الساكن'),
              content: Text('سيتم حذف ${resident.name} من بيانات العرض وإتاحة السرير المرتبط به. هل تريد المتابعة؟'),
              actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC2414B)), child: const Text('حذف'))],
            ));
            if (confirmed == true) {
              widget.store.deleteResident(resident.id);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الساكن من بيانات العرض.')));
            }
          }),
        ]),
      )),
    );
  }

  Future<void> _showTransfer(BuildContext context, Resident resident) async {
    final freeBeds = widget.store.freeBeds;
    if (freeBeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد أسرّة متاحة للنقل حالياً.')));
      return;
    }
    String selected = freeBeds.first.id;
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('نقل الساكن إلى سرير آخر'),
      content: DropdownButtonFormField<String>(
        value: selected,
        isExpanded: true,
        items: freeBeds.map((bed) => DropdownMenuItem(value: bed.id, child: Text('${widget.store.buildingFor(widget.store.roomFor(bed.roomId)?.buildingId)?.name ?? ''} • ${widget.store.roomFor(bed.roomId)?.name ?? ''} • ${bed.label}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) { if (value != null) setDialogState(() => selected = value); },
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), FilledButton(onPressed: () {
        final success = widget.store.assignBed(resident.id, selected);
        if (success) widget.store.addRequest(requestType: 'نقل سرير', resident: resident, details: 'طلب نقل إلى ${widget.store.bedFor(selected)?.label ?? selected}');
        Navigator.pop(dialogContext);
        messenger.showSnackBar(SnackBar(content: Text(success ? 'تم تحديث التسكين وإنشاء سجل طلب النقل.' : 'تعذر النقل؛ تحقق من توفر السرير.')));
      }, child: const Text('تأكيد النقل'))],
    )));
  }
}

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.store, required this.resident, required this.onEdit});
  final HousingStore store;
  final Resident resident;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: navy.withOpacity(.07), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.person_outline_rounded, color: navy, size: 24)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(resident.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 3),
          Text('${resident.employeeCode} • ${resident.jobTitle}', style: const TextStyle(fontSize: 11, color: muted)),
        ])),
        IconButton(onPressed: onEdit, icon: const Icon(Icons.more_horiz_rounded, color: muted), tooltip: 'إجراءات'),
      ]),
      const Divider(height: 20, color: line),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.apartment_rounded, size: 16, color: teal),
        const SizedBox(width: 7),
        Expanded(child: Text(store.locationFor(resident), style: const TextStyle(fontSize: 11, color: navy, fontWeight: FontWeight.w600))),
        StatusPill(resident.attendanceStatus),
      ]),
      const SizedBox(height: 9),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _MiniInfo(icon: Icons.business_outlined, label: resident.company),
        if (resident.department.isNotEmpty) _MiniInfo(icon: Icons.groups_outlined, label: resident.department),
        if (resident.serviceType.isNotEmpty) _MiniInfo(icon: Icons.category_outlined, label: 'خدمة: ${resident.serviceType}'),
        _MiniInfo(icon: Icons.schedule_rounded, label: '${resident.shiftTable.isNotEmpty ? resident.shiftTable : resident.shift}${resident.rotation.isNotEmpty ? ' • ${resident.rotation}' : ''}'),
        if (resident.dutyStatus.isNotEmpty)
          _MiniInfo(
            icon: resident.onDuty ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
            label: 'نظام الدوام: ${resident.dutyStatus}${resident.dutyCycleLabel.isNotEmpty ? ' • ${resident.dutyCycleLabel} يوم' : ''}',
          ),
        if (resident.transportType.isNotEmpty) _MiniInfo(icon: Icons.directions_bus_outlined, label: resident.transportType),
        if (resident.cardNumber.isNotEmpty) _MiniInfo(icon: Icons.badge_outlined, label: 'بطاقة: ${resident.cardNumber}'),
        if (resident.birthDate != null) _MiniInfo(icon: Icons.cake_outlined, label: 'ميلاد: ${resident.birthDateLabel}'),
        if (resident.birthPlace.isNotEmpty) _MiniInfo(icon: Icons.place_outlined, label: resident.birthPlace),
      ]),
    ]),
  );
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(9)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: muted), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, color: muted))]),
  );
}

class _AddResidentSheet extends StatefulWidget {
  const _AddResidentSheet({required this.store});
  final HousingStore store;
  @override
  State<_AddResidentSheet> createState() => _AddResidentSheetState();
}

class _AddResidentSheetState extends State<_AddResidentSheet> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final code = TextEditingController();
  final job = TextEditingController();
  final phone = TextEditingController();
  final departure = TextEditingController();
  final workDays = TextEditingController();
  final restDays = TextEditingController();
  final cardNumber = TextEditingController();
  final birthPlace = TextEditingController();
  String? company;
  String? department;
  String? serviceType;
  String? dutyType;
  String? transport;
  String? gender;
  String? contractorId;
  DateTime? cycleStart;
  DateTime? birthDate;
  bool _birthError = false;
  String selectedBed = '';

  bool get isContractorWorker => contractorId != null;

  @override
  void dispose() {
    name.dispose(); code.dispose(); job.dispose(); phone.dispose(); departure.dispose();
    workDays.dispose(); restDays.dispose(); cardNumber.dispose(); birthPlace.dispose(); super.dispose();
  }

  InputDecoration _dec(String label, [IconData? icon]) => InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon));

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final freeBeds = store.freeBeds;
    final contractors = store.contractors;
    return Container(
      height: MediaQuery.of(context).size.height * .92,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(child: Form(key: formKey, child: ListView(padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 22), children: [
        Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(5)))),
        const SizedBox(height: 18),
        const Text('إضافة ساكن جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 5),
        const Text('أكمل بيانات الموظف كاملة. الحقول ذات القائمة منسدلة لضمان توحيد البيانات.', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 18),
        _field(name, 'اسم الموظف', Icons.person_outline, requiredField: true),
        const SizedBox(height: 10),
        _field(code, 'الرقم الوظيفي', Icons.badge_outlined, requiredField: true),
        const SizedBox(height: 10),
        _field(job, 'المسمى الوظيفي', Icons.work_outline),
        const SizedBox(height: 10),
        _dropdown('الشركة / المتعهد', Icons.business_outlined, company, store.companyOptions, (v) => setState(() => company = v)),
        const SizedBox(height: 10),
        _dropdown('الإدارة / القسم', Icons.groups_outlined, department, store.departmentOptions, (v) => setState(() => department = v)),
        const SizedBox(height: 10),
        _dropdown('نوع الخدمة', Icons.category_outlined, serviceType, store.serviceTypeOptions, (v) => setState(() => serviceType = v)),
        const SizedBox(height: 10),
        _dropdown('نوع الدوام', Icons.schedule_outlined, dutyType, store.dutyTypeOptions, (v) => setState(() => dutyType = v)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _dropdown('تصنيف النقل', Icons.directions_bus_outlined, transport, store.transportTypeOptions, (v) => setState(() => transport = v))),
          const SizedBox(width: 10),
          Expanded(child: _dropdown('الجنس', Icons.wc_outlined, gender, store.genderOptions, (v) => setState(() => gender = v))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(phone, 'الجوال', Icons.phone_outlined)),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: departure, decoration: _dec('وقت المغادرة', Icons.watch_later_outlined), keyboardType: TextInputType.datetime)),
        ]),
        const SizedBox(height: 14),
        const Text('نظام الدوام (دورة)', style: TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: cycleStart ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (picked != null) setState(() => cycleStart = picked);
            },
            child: InputDecorator(decoration: _dec('تاريخ بداية الدورة', Icons.event_outlined), child: Text(cycleStart == null ? 'اختر التاريخ' : '${cycleStart!.year}-${cycleStart!.month.toString().padLeft(2, '0')}-${cycleStart!.day.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 13, color: cycleStart == null ? muted : navy))),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: workDays, decoration: _dec('أيام العمل'), keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: restDays, decoration: _dec('أيام الراحة'), keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        _dropdown('المتعهد/المقاول التابع له', Icons.handshake_outlined, contractorId, [''], (v) => setState(() => contractorId = (v == null || v.isEmpty) ? null : v), items: [const DropdownMenuItem(value: '', child: Text('موظف (لا يوجد)')), ...contractors.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))]),
        if (isContractorWorker) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFF2673B8).withOpacity(.08), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2673B8)),
              SizedBox(width: 8),
              Expanded(child: Text('بيانات إجبارية لعمال المتعهدين والمقاولين', style: TextStyle(fontSize: 11, color: Color(0xFF2673B8), fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: cardNumber,
            decoration: _dec('رقم البطاقة *', Icons.badge_outlined),
            validator: (v) => v == null || v.trim().isEmpty ? 'رقم البطاقة مطلوب' : null,
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(context: context, initialDate: birthDate ?? DateTime(now.year - 25, now.month, now.day), firstDate: DateTime(1940), lastDate: now, helpText: 'تاريخ الميلاد');
              if (picked != null) setState(() { birthDate = picked; _birthError = false; });
            },
            child: InputDecorator(
              decoration: _dec('تاريخ الميلاد *', Icons.cake_outlined).copyWith(errorText: _birthError ? 'تاريخ الميلاد مطلوب' : null),
              child: Text(birthDate == null ? 'اختر التاريخ' : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 13, color: birthDate == null ? muted : navy)),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: birthPlace,
            decoration: _dec('مكان الميلاد *', Icons.place_outlined),
            validator: (v) => v == null || v.trim().isEmpty ? 'مكان الميلاد مطلوب' : null,
          ),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selectedBed,
          isExpanded: true,
          decoration: _dec('تخصيص سرير (اختياري)', Icons.bed_outlined),
          items: [const DropdownMenuItem(value: '', child: Text('بدون تخصيص حالياً')), ...freeBeds.map((bed) => DropdownMenuItem(value: bed.id, child: Text('${store.buildingFor(store.roomFor(bed.roomId)?.buildingId)?.name ?? ''} • ${store.roomFor(bed.roomId)?.name ?? ''} • ${bed.label}', overflow: TextOverflow.ellipsis)))],
          onChanged: (v) => setState(() => selectedBed = v ?? ''),
        ),
        const SizedBox(height: 22),
        PrimaryAction(label: 'حفظ بيانات الساكن', icon: Icons.check_circle_outline_rounded, onPressed: _save),
      ]))),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool requiredField = false}) => TextFormField(
    controller: controller,
    decoration: _dec(label, icon),
    validator: requiredField ? (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null : null,
  );

  Widget _dropdown(String label, IconData icon, String? value, List<String> options, ValueChanged<String?> onChanged, {List<DropdownMenuItem<String>>? items}) => DropdownButtonFormField<String>(
    value: value,
    isExpanded: true,
    decoration: _dec(label, icon),
    items: items ?? options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
    onChanged: onChanged,
  );

  void _save() {
    final formOk = formKey.currentState!.validate();
    final birthOk = !isContractorWorker || birthDate != null;
    if (!birthOk) setState(() => _birthError = true);
    if (!formOk || !birthOk) return;
    widget.store.addResident(
      name: name.text,
      employeeCode: code.text,
      jobTitle: job.text,
      company: company ?? '',
      department: department ?? '',
      shift: dutyType ?? '',
      rotation: '',
      serviceType: serviceType ?? '',
      phone: phone.text,
      gender: gender ?? '',
      transportType: transport ?? '',
      departureTime: departure.text,
      cardNumber: cardNumber.text,
      birthDate: birthDate,
      birthPlace: birthPlace.text,
      bedId: selectedBed.isEmpty ? null : selectedBed,
      contractorId: contractorId,
      dutyCycleStart: cycleStart,
      dutyWorkDays: int.tryParse(workDays.text.trim()) ?? 0,
      dutyRestDays: int.tryParse(restDays.text.trim()) ?? 0,
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('تمت إضافة الساكن إلى القائمة.')));
    HapticFeedback.selectionClick();
  }
}
