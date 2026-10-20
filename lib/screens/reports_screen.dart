import 'package:flutter/material.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';
import '../utils/csv_export.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.store});
  final HousingStore store;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String periodId = 'all';
  DateTime? from;
  DateTime? to;

  HousingStore get store => widget.store;

  (DateTime?, DateTime?) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (periodId) {
      case 'today':
        return (today, today);
      case 'yesterday':
        final y = today.subtract(const Duration(days: 1));
        return (y, y);
      case 'week':
        return (today.subtract(const Duration(days: 6)), today);
      case 'month':
        return (today.subtract(const Duration(days: 29)), today);
      case 'thisMonth':
        return (DateTime(today.year, today.month, 1), today);
      case 'custom':
        return (from, to);
      default:
        return (null, null);
    }
  }

  bool _inRange(DateTime? d) {
    final r = _range;
    if (r.$1 == null && r.$2 == null) return true;
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (r.$1 != null && day.isBefore(r.$1!)) return false;
    if (r.$2 != null && day.isAfter(r.$2!)) return false;
    return true;
  }

  DateTime get _referenceDate => _range.$2 ?? DateTime.now();

  String get _rangeLabel {
    final r = _range;
    if (r.$1 == null && r.$2 == null) return 'كل الفترات';
    String f(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final a = r.$1 == null ? '…' : f(r.$1!);
    final b = r.$2 == null ? '…' : f(r.$2!);
    return '$a ← $b';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final scoped = store.housingResidents.where((r) => _inRange(r.checkInDate)).toList();
      final present = scoped.where((r) => r.attendanceStatus == 'متواجد').length;
      final companyRows = store.companyStatsOf(scoped);
      final buildingRows = store.buildingStatsOf(scoped);
      final reqs = store.requests.where((r) => _inRange(r.createdAt)).toList();
      final ref = _referenceDate;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        Row(children: [
          const Expanded(child: SectionTitle('تقارير السكن', subtitle: 'ملخصات الشركات والسكنات والفترات')),
          _iconButton(Icons.file_download_outlined, 'تصدير التقرير', () => _export(companyRows, buildingRows, scoped, present)),
        ]),
        const SizedBox(height: 4),
        _periodBar(),
        const SizedBox(height: 8),
        Text('النطاق: $_rangeLabel • مرجع الدوام: ${ref.year}-${ref.month.toString().padLeft(2, '0')}-${ref.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: muted)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: MetricCard(title: 'إجمالي المرتبطين', value: '${scoped.length}', icon: Icons.groups_2_rounded, color: navy)),
          const SizedBox(width: 10),
          Expanded(child: MetricCard(title: 'إجمالي المتواجدين', value: '$present', icon: Icons.how_to_reg_rounded, color: teal)),
          const SizedBox(width: 10),
          Expanded(child: MetricCard(title: 'النسبة', value: '${scoped.isEmpty ? 0 : ((present / scoped.length) * 100).round()}%', icon: Icons.percent_rounded, color: const Color(0xFF2877B9))),
        ]),
        const SizedBox(height: 12),
        _statCard('التقرير على مستوى الشركات', Icons.business_center_outlined, companyRows, 'شركة/جهة'),
        const SizedBox(height: 12),
        _statCard('التقرير على مستوى السكنات', Icons.apartment_rounded, buildingRows, 'سكن'),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('توزيع حالة الحضور', style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 7),
          Text('حالة المتابعة المسجلة حالياً للنطاق المحدد (${scoped.length} ساكن).', style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 16),
          _StatusBar(label: 'متواجد', count: present, total: scoped.length, color: teal),
          _StatusBar(label: 'خارج السكن', count: scoped.where((r) => r.attendanceStatus == 'خارج السكن').length, total: scoped.length, color: const Color(0xFF2877B9)),
          _StatusBar(label: 'إجازة', count: scoped.where((r) => r.attendanceStatus == 'إجازة').length, total: scoped.length, color: const Color(0xFFB27C18)),
          _StatusBar(label: 'غائب', count: scoped.where((r) => r.attendanceStatus == 'غائب').length, total: scoped.length, color: const Color(0xFFC2414B)),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('التواجد حسب نظام الدوام', style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 7),
          Text('الحالة الدورية المحسوبة حسب تاريخ بداية الدورة لتاريخ المرجع ($_rangeLabel).', style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final known = scoped.where((r) => r.dutyStatusOn(ref).isNotEmpty).toList();
            final on = known.where((r) => r.dutyStatusOn(ref) == 'مداوم').length;
            return Column(children: [
              _StatusBar(label: 'مداوم (على رأس الدوام)', count: on, total: known.length, color: teal),
              _StatusBar(label: 'إجازة دورية', count: known.length - on, total: known.length, color: const Color(0xFFB27C18)),
              Align(alignment: Alignment.centerLeft, child: Text('موظفون بدون نظام دوام معروف: ${scoped.length - known.length}', style: const TextStyle(fontSize: 10, color: muted))),
            ]);
          }),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('سكان نوع الخدمة «سكن» — الدائمون', style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 7),
          const Text('عدد السكان الذين يشمل نوع خدمتهم كلمة «سكن» (منفردة أو مجتمعة) وحالتهم الدورية «مداوم» على تاريخ المرجع.', style: TextStyle(color: muted, fontSize: 11, height: 1.5)),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final housingOn = scoped.where((r) => r.isHousingService && r.dutyStatusOn(ref) == 'مداوم').toList();
            final byType = <String, int>{};
            for (final r in housingOn) {
              final k = r.serviceTypeLabel;
              byType[k] = (byType[k] ?? 0) + 1;
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${housingOn.length}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: teal)),
                const SizedBox(width: 8),
                const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('ساكن مداوم', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 12),
              ...byType.entries.map((e) => _StatusBar(label: 'نوع الخدمة: ${e.key}', count: e.value, total: housingOn.length, color: e.key.contains('نقل') ? const Color(0xFF2877B9) : teal)),
            ]);
          }),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('نسبة الإشغال حسب المبنى', style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 15),
          for (final building in store.buildings) ...[
            Builder(builder: (context) {
              final roomIds = store.rooms.where((r) => r.buildingId == building.id).map((r) => r.id).toSet();
              final beds = store.beds.where((b) => roomIds.contains(b.roomId)).length;
              final occupied = store.beds.where((b) => roomIds.contains(b.roomId) && store.residentOnBed(b.id) != null).length;
              final percent = beds == 0 ? 0.0 : occupied / beds;
              return Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(building.name, style: const TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w800))), Text('$occupied / $beds سرير', style: const TextStyle(fontSize: 11, color: muted))]),
                const SizedBox(height: 7),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: percent, minHeight: 9, backgroundColor: canvas, color: teal)),
                const SizedBox(height: 4),
                Text('${(percent * 100).round()}% إشغال', style: const TextStyle(fontSize: 10, color: muted)),
              ]));
            }),
          ],
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ملخص الطلبات خلال الفترة', style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 12),
          _RequestSummary(label: 'قيد المراجعة', count: reqs.where((r) => r.status == 'قيد المراجعة').length, color: const Color(0xFFB27C18)),
          _RequestSummary(label: 'معتمدة', count: reqs.where((r) => r.status == 'معتمد').length, color: teal),
          _RequestSummary(label: 'مرفوضة', count: reqs.where((r) => r.status == 'مرفوض').length, color: const Color(0xFFC2414B)),
          const SizedBox(height: 4),
          Text('سكان جدد خلال الفترة: ${scoped.length} / إجمالي السكان: ${store.housingResidentCount}', style: const TextStyle(fontSize: 10, color: muted)),
        ])),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF6E4), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFF2E0B8))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: Color(0xFF9A6700), size: 18), SizedBox(width: 9), Expanded(child: Text('تعتمد التقارير على بيانات السكن والموظفين المصحّحة من ملف Excel، ونظام الدوام من تاريخ بداية الدورة. تُحسب الفترة حسب تاريخ التسكين.', style: TextStyle(fontSize: 11, color: Color(0xFF78520A), height: 1.5)))])),
      ]);
    },
  );

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
    message: tooltip,
    child: Material(color: canvas, borderRadius: BorderRadius.circular(12), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 20, color: teal)))),
  );

  Widget _periodBar() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
    for (final p in kQuickPeriods)
      Padding(padding: const EdgeInsets.only(left: 7), child: ChoiceChip(
        label: Text(p.label), selected: periodId == p.id,
        onSelected: (_) => setState(() { periodId = p.id; if (p.id == 'custom') {} }),
        selectedColor: teal.withOpacity(.14), labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: periodId == p.id ? teal : muted),
        side: BorderSide(color: periodId == p.id ? teal.withOpacity(.3) : line),
      )),
    Padding(padding: const EdgeInsets.only(left: 7), child: ActionChip(
      avatar: Icon(Icons.date_range_rounded, size: 16, color: periodId == 'custom' ? teal : muted),
      label: Text(periodId == 'custom' ? _rangeLabel : 'من / إلى', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: periodId == 'custom' ? teal : muted)),
      backgroundColor: periodId == 'custom' ? teal.withOpacity(.12) : canvas,
      side: BorderSide(color: periodId == 'custom' ? teal.withOpacity(.3) : line),
      onPressed: _pickCustomRange,
    )),
  ]));

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: (from != null && to != null) ? DateTimeRange(start: from!, end: to!) : null,
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() { periodId = 'custom'; from = picked.start; to = picked.end; });
    } else {
      setState(() => periodId = 'custom');
    }
  }

  Widget _statCard(String title, IconData icon, List<AttendanceStat> rows, String unit) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, size: 18, color: teal), const SizedBox(width: 8), Text(title, style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 15))]),
    const SizedBox(height: 14),
    if (rows.isEmpty)
      const Text('لا توجد بيانات في هذا النطاق.', style: TextStyle(fontSize: 12, color: muted))
    else ...[
      Row(children: const [
        Expanded(flex: 4, child: Text('الجهة', style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('مرتبطون', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('متواجدون', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('النسبة', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w800))),
      ]),
      const Divider(height: 16, color: line),
      ...rows.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(children: [
        Row(children: [
          Expanded(flex: 4, child: Text(s.label, style: const TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text('${s.total}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w900))),
          Expanded(flex: 2, child: Text('${s.present}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: teal, fontWeight: FontWeight.w900))),
          Expanded(flex: 2, child: Text('${s.percentRounded}%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: s.percent, minHeight: 6, backgroundColor: canvas, color: teal)),
      ]))),
    ],
  ]));

  Future<void> _export(List<AttendanceStat> companies, List<AttendanceStat> buildings, List<Resident> scoped, int present) async {
    final header = ['المستوى', 'الجهة', 'إجمالي المرتبطين', 'إجمالي المتواجدين', 'غير المتواجدين', 'النسبة %'];
    final data = <List<String>>[
      ['ملخص', 'الإجمالي العام', '${scoped.length}', '$present', '${scoped.length - present}', '${scoped.isEmpty ? 0 : ((present / scoped.length) * 100).round()}'],
      for (final s in companies) ['شركة/جهة', s.label, '${s.total}', '${s.present}', '${s.away}', '${s.percentRounded}'],
      for (final s in buildings) ['سكن', s.label, '${s.total}', '${s.present}', '${s.away}', '${s.percentRounded}'],
    ];
    final csv = buildCsv(header, data);
    await copyCsv(context, csv, 'تقرير الشركات والسكنات — $_rangeLabel');
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.label, required this.count, required this.total, required this.color});
  final String label;
  final int count;
  final int total;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(children: [
    Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w700))), Text('$count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900)), const SizedBox(width: 5), Text(total == 0 ? '—' : '(${((count / total) * 100).round()}%)', style: const TextStyle(fontSize: 10, color: muted))]),
    const SizedBox(height: 7),
    ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: total == 0 ? 0 : count / total, minHeight: 8, backgroundColor: canvas, color: color)),
  ]));
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(color: navy, fontSize: 12))), Text('$count طلب', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12))]));
}
