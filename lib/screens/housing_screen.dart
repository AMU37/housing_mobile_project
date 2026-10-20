import 'package:flutter/material.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';

class HousingScreen extends StatelessWidget {
  const HousingScreen({super.key, required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      children: [
        const SectionTitle('المباني والغرف والأسرّة', subtitle: 'عرض مرئي للإشغال والتسكين وإتاحة الأسرة'),
        Row(children: [
          Expanded(child: _SmallStat(label: 'إجمالي الأسرّة', value: '${store.totalBeds}', icon: Icons.bed_rounded, color: navy)),
          const SizedBox(width: 8),
          Expanded(child: _SmallStat(label: 'مشغولة', value: '${store.occupiedBeds}', icon: Icons.person_pin_circle_outlined, color: teal)),
          const SizedBox(width: 8),
          Expanded(child: _SmallStat(label: 'متاحة', value: '${store.availableBeds}', icon: Icons.check_circle_outline, color: const Color(0xFF2877B9))),
        ]),
        const SizedBox(height: 13),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.pie_chart_outline_rounded, color: teal), const SizedBox(width: 9), const Expanded(child: Text('نسبة إشغال السكن', style: TextStyle(color: navy, fontWeight: FontWeight.w800))), Text('${store.occupancyPercent}%', style: const TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 18))]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(30), child: LinearProgressIndicator(value: store.occupancyPercent / 100, minHeight: 10, backgroundColor: canvas, color: teal)),
            const SizedBox(height: 8),
            const Text('اضغط على أي سرير متاح لتسكين موظف، أو على سرير مشغول لعرض بيانات الساكن.', style: TextStyle(fontSize: 11, color: muted)),
          ]),
        ),
        const SizedBox(height: 18),
        for (final building in store.buildings)
          _BuildingCard(store: store, building: building),
        const SizedBox(height: 8),
        SectionTitle('جدولة تناوب الأسرّة', subtitle: 'مواعيد تسليم السرير من ساكن إلى آخر', trailing: Text('${store.rotations.where((r) => r.status == 'مجدول').length} مجدول', style: const TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.w800))),
        if (store.rotations.isEmpty)
          const AppCard(child: EmptyState(title: 'لا توجد عمليات تناوب مجدولة', subtitle: 'يمكنك جدولة تناوب من تفاصيل السرير المشغول.', icon: Icons.swap_horiz_rounded))
        else
          for (final rotation in store.rotations) _RotationCard(store: store, rotation: rotation),
      ],
    ),
  );
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 20), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 21, color: navy, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 10, color: muted))]));
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({required this.store, required this.building});
  final HousingStore store;
  final BuildingUnit building;

  @override
  Widget build(BuildContext context) {
    final rooms = store.rooms.where((r) => r.buildingId == building.id).toList();
    final bedIds = rooms.expand((r) => r.bedIds).toList();
    final occupied = bedIds.where((id) => store.residentOnBed(id) != null).length;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          leading: Container(width: 43, height: 43, decoration: BoxDecoration(color: navy.withOpacity(.08), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.apartment_rounded, color: navy)),
          title: Text(building.name, style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 14)),
          subtitle: Text('${building.location} • ${rooms.length} غرف', style: const TextStyle(color: muted, fontSize: 11)),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$occupied / ${bedIds.length}', style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 13)), const Text('مشغولة', style: TextStyle(color: muted, fontSize: 10))]),
          children: [
            for (final room in rooms) ...[
              Padding(padding: const EdgeInsets.fromLTRB(2, 4, 2, 8), child: Row(children: [const Icon(Icons.meeting_room_outlined, size: 17, color: teal), const SizedBox(width: 7), Expanded(child: Text(room.name, style: const TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 12))), Text('${room.bedIds.where((id) => store.residentOnBed(id) != null).length} / ${room.bedIds.length}', style: const TextStyle(color: muted, fontSize: 11))])),
              GridView.builder(
                itemCount: room.bedIds.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.05, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemBuilder: (context, index) {
                  final bed = store.bedFor(room.bedIds[index])!;
                  final occupant = store.residentOnBed(bed.id);
                  return _BedTile(bed: bed, occupant: occupant, onTap: () => _onBedTap(context, bed, occupant));
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onBedTap(BuildContext context, BedUnit bed, Resident? occupant) async {
    final messenger = ScaffoldMessenger.of(context);
    if (occupant != null) {
      await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 25),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('بيانات السرير', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 12),
          Text('${bed.label} • ${store.roomFor(bed.roomId)?.name ?? ''}', style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(occupant.name, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800)),
          Text('${occupant.employeeCode} • ${occupant.jobTitle}', style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 8),
          StatusPill(occupant.attendanceStatus),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () { store.unassignBed(occupant.id); Navigator.pop(sheetContext); }, icon: const Icon(Icons.logout_rounded), label: const Text('إخلاء السرير'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(sheetContext); _scheduleRotation(context, bed, occupant); }, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('جدولة تناوب'))),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: () { Navigator.pop(sheetContext); store.addRequest(requestType: 'صيانة غرفة', resident: occupant, details: 'طلب صيانة مرتبط بموقع ${store.locationFor(occupant)}'); messenger.showSnackBar(const SnackBar(content: Text('تم إنشاء طلب صيانة.'))); }, icon: const Icon(Icons.build_outlined), label: const Text('إنشاء طلب صيانة'))),
        ]),
      )));
      return;
    }
    final unassigned = store.housingResidents.where((r) => !r.isAssigned).toList();
    if (unassigned.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('لا توجد أسماء غير مسكنة. يمكنك إضافة ساكن من صفحة السكان.')));
      return;
    }
    String selectedId = unassigned.first.id;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text('تسكين في ${bed.label}'),
      content: DropdownButtonFormField<String>(
        value: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'اختر الموظف'),
        items: unassigned.map((r) => DropdownMenuItem(value: r.id, child: Text('${r.name} • ${r.employeeCode}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) { if (value != null) setDialogState(() => selectedId = value); },
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), FilledButton(onPressed: () {
        final resident = store.residents.firstWhere((r) => r.id == selectedId);
        final success = store.assignBed(selectedId, bed.id);
        if (success) store.addRequest(requestType: 'تسكين جديد', resident: resident, details: 'تخصيص ${bed.label} في ${store.roomFor(bed.roomId)?.name ?? ''}');
        Navigator.pop(dialogContext);
        messenger.showSnackBar(SnackBar(content: Text(success ? 'تم تخصيص السرير وإنشاء سجل طلب.' : 'لم يكتمل التسكين.')));
      }, child: const Text('تأكيد التسكين'))],
    )));
  }
  Future<void> _scheduleRotation(BuildContext context, BedUnit bed, Resident outgoing) async {
    final messenger = ScaffoldMessenger.of(context);
    final candidates = store.housingResidents.where((r) => r.id != outgoing.id).toList();
    if (candidates.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('أضف ساكناً آخر أولاً لجدولة التناوب.')));
      return;
    }
    String incomingId = candidates.first.id;
    DateTime scheduledFor = DateTime.now().add(const Duration(days: 1));
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('جدولة تناوب السرير'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${bed.label} • الساكن الحالي: ${outgoing.name}', style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: incomingId, isExpanded: true, decoration: const InputDecoration(labelText: 'الساكن التالي'), items: candidates.map((r) => DropdownMenuItem(value: r.id, child: Text('${r.name} • ${r.employeeCode}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) setDialogState(() => incomingId = value); }),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () async {
          final date = await showDatePicker(context: context, initialDate: scheduledFor, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
          if (date != null) setDialogState(() => scheduledFor = date);
        }, icon: const Icon(Icons.calendar_month_outlined), label: Text('موعد التناوب: ${scheduledFor.year}-${scheduledFor.month.toString().padLeft(2, '0')}-${scheduledFor.day.toString().padLeft(2, '0')}')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), FilledButton(onPressed: () {
        store.scheduleBedRotation(bedId: bed.id, outgoingResidentId: outgoing.id, incomingResidentId: incomingId, scheduledFor: scheduledFor);
        Navigator.pop(dialogContext);
        messenger.showSnackBar(const SnackBar(content: Text('تمت جدولة التناوب وإضافة طلب للمراجعة.')));
      }, child: const Text('حفظ الجدولة'))],
    )));
  }
}

class _BedTile extends StatelessWidget {
  const _BedTile({required this.bed, required this.occupant, required this.onTap});
  final BedUnit bed;
  final Resident? occupant;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isOccupied = occupant != null;
    final color = isOccupied ? teal : const Color(0xFF2877B9);
    return Material(
      color: color.withOpacity(.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(.23))),
          child: Row(children: [
            Icon(isOccupied ? Icons.bed_rounded : Icons.bed_outlined, color: color, size: 21),
            const SizedBox(width: 7),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bed.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
              Text(isOccupied ? occupant!.name : 'متاح للتسكين', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: muted)),
            ])),
          ]),
        ),
      ),
    );
  }
}


class _RotationCard extends StatelessWidget {
  const _RotationCard({required this.store, required this.rotation});
  final HousingStore store;
  final BedRotation rotation;
  @override
  Widget build(BuildContext context) {
    final outgoing = store.residentById(rotation.outgoingResidentId);
    final incoming = store.residentById(rotation.incomingResidentId);
    final bed = store.bedFor(rotation.bedId);
    final date = '${rotation.scheduledFor.year}-${rotation.scheduledFor.month.toString().padLeft(2, '0')}-${rotation.scheduledFor.day.toString().padLeft(2, '0')}';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.swap_horiz_rounded, color: teal),
          const SizedBox(width: 8),
          Expanded(child: Text('${bed?.label ?? 'سرير'} • $date', style: const TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w900))),
          StatusPill(rotation.status),
        ]),
        const SizedBox(height: 8),
        Text('${outgoing?.name ?? 'ساكن سابق'}  ←  ${incoming?.name ?? 'ساكن تالٍ'}', style: const TextStyle(color: navy, fontSize: 12)),
        if (rotation.status == 'مجدول') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => store.cancelBedRotation(rotation.id), child: const Text('إلغاء الجدولة'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () {
              final success = store.executeBedRotation(rotation.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'تم تنفيذ التناوب وتحديث التسكين.' : 'تعذر تنفيذ التناوب؛ تحقق من بيانات الساكنين.')));
            }, child: const Text('تنفيذ التناوب'))),
          ]),
        ],
      ]),
    );
  }
}
