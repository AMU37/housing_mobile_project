import 'package:flutter/material.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store, required this.onNavigate});
  final HousingStore store;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF142A43), Color(0xFF1C4962)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(children: [
            const Positioned(left: -15, bottom: -23, child: Icon(Icons.apartment_rounded, size: 112, color: Color(0x1835D2C4))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(30)), child: const Text('لوحة التحكم التشغيلية', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
              const SizedBox(height: 12),
              const Text('إدارة السكن بوضوح\nمن مكان واحد', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.35)),
              const SizedBox(height: 8),
              const Text('التسكين • الحضور • الإجازات • إشغال الأسرّة', style: TextStyle(color: Color(0xFFD7E5EF), fontSize: 12)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _HeroFigure(value: '${store.occupancyPercent}%', label: 'نسبة إشغال الأسرّة')),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(child: _HeroFigure(value: '${store.housingResidentCount}', label: 'إجمالي الساكنين')),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(child: _HeroFigure(value: '${store.requests.where((r) => r.status == 'قيد المراجعة').length}', label: 'طلبات قيد المراجعة')),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        const SectionTitle('ملخص السكن', subtitle: 'مؤشرات توضيحية قابلة للتحديث من النظام'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.28,
          children: [
            MetricCard(title: 'الأسرّة المشغولة', value: '${store.occupiedBeds}', icon: Icons.bed_rounded, color: teal, caption: 'من أصل ${store.totalBeds} سرير'),
            MetricCard(title: 'الأسرّة المتاحة', value: '${store.availableBeds}', icon: Icons.bed_outlined, color: const Color(0xFF2877B9), caption: 'جاهزة للتسكين'),
            MetricCard(title: 'متواجدون بالسكن', value: '${store.countStatus('متواجد')}', icon: Icons.home_rounded, color: const Color(0xFF16846B), caption: 'حسب حالة المتابعة'),
            MetricCard(title: 'في إجازة', value: '${store.countStatus('إجازة')}', icon: Icons.luggage_rounded, color: const Color(0xFFB27C18), caption: 'خارج السكن بإجازة'),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('الوصول السريع', subtitle: 'انتقل إلى المهام الأكثر استخداماً'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.55,
          children: [
            _QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'إضافة ساكن', color: teal, onTap: () => onNavigate('residents')),
            _QuickAction(icon: Icons.bed_rounded, label: 'توزيع الأسرّة', color: navy, onTap: () => onNavigate('housing')),
            _QuickAction(icon: Icons.fact_check_rounded, label: 'الحضور والإجازات', color: const Color(0xFFB27C18), onTap: () => onNavigate('operations')),
            _QuickAction(icon: Icons.assessment_rounded, label: 'التقارير', color: const Color(0xFF2877B9), onTap: () => onNavigate('reports')),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('آخر الطلبات', subtitle: 'حالة معاملات السكن الأخيرة', trailing: Icon(Icons.history_rounded, color: muted)),
        if (store.requests.isEmpty)
          const AppCard(child: EmptyState(title: 'لا توجد طلبات', subtitle: 'ستظهر الطلبات الجديدة هنا.'))
        else
          ...store.requests.take(3).map((request) => _RequestPreview(request: request)),
      ],
    ),
  );
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 21)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Color(0xFFD7E5EF), fontSize: 10), maxLines: 2),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    onTap: onTap,
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy))),
      const Icon(Icons.chevron_left_rounded, color: muted, size: 18),
    ]),
  );
}

class _RequestPreview extends StatelessWidget {
  const _RequestPreview({required this.request});
  final HousingRequest request;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: teal.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.assignment_outlined, color: teal)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(request.requestType, style: const TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 3),
        Text('${request.residentName} • ${request.id}', style: const TextStyle(color: muted, fontSize: 11)),
      ])),
      StatusPill(request.status),
    ]),
  );
}
