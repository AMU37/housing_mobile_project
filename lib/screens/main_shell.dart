import 'package:flutter/material.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';
import 'dashboard_screen.dart';
import 'residents_screen.dart';
import 'housing_screen.dart';
import 'operations_screen.dart';
import 'reports_screen.dart';
import 'contractor_approvals_screen.dart';
import 'admin_screen.dart';

class _TabDef {
  const _TabDef(this.key, this.label, this.icon, this.selectedIcon);
  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});
  final HousingStore store;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 0;

  static const _allTabs = <_TabDef>[
    _TabDef('dashboard', 'الرئيسية', Icons.grid_view_rounded, Icons.grid_view_rounded),
    _TabDef('residents', 'السكان', Icons.people_alt_outlined, Icons.people_alt_rounded),
    _TabDef('housing', 'السكن', Icons.bed_outlined, Icons.bed_rounded),
    _TabDef('operations', 'المتابعة', Icons.fact_check_outlined, Icons.fact_check_rounded),
    _TabDef('reports', 'التقارير', Icons.bar_chart_rounded, Icons.bar_chart_rounded),
  ];

  List<_TabDef> get _visibleTabs {
    final allowed = widget.store.availableViewTabs;
    final tabs = _allTabs.where((t) => allowed.contains(t.key)).toList();
    if (tabs.isEmpty) {
      return const [_TabDef('operations', 'المتابعة', Icons.fact_check_outlined, Icons.fact_check_rounded)];
    }
    return tabs;
  }

  Widget _pageFor(String key) {
    switch (key) {
      case 'dashboard':
        return DashboardScreen(store: widget.store, onNavigate: _navigateToKey);
      case 'residents':
        return ResidentsScreen(store: widget.store);
      case 'housing':
        return HousingScreen(store: widget.store);
      case 'operations':
        return OperationsScreen(store: widget.store);
      case 'reports':
        return ReportsScreen(store: widget.store);
      default:
        return OperationsScreen(store: widget.store);
    }
  }

  void _navigateToKey(String key) {
    final tabs = _visibleTabs;
    final i = tabs.indexWhere((t) => t.key == key);
    if (i >= 0) setState(() => selectedIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs;
    if (selectedIndex >= tabs.length) selectedIndex = 0;
    final pages = tabs.map((t) => _pageFor(t.key)).toList();
    final canSupervise = widget.store.can('requests.supervise');
    final canSecurity = widget.store.can('requests.security');
    final pending = canSecurity && !canSupervise
        ? widget.store.securityPendingRequests.length
        : widget.store.housingPendingRequests.length;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إدارة الشؤون', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: navy)),
            Text(widget.store.currentRole?.name ?? 'إدارة السكن والموظفين', style: const TextStyle(fontSize: 10, color: muted)),
          ])),
        ]),
        actions: [
          if (canSupervise || canSecurity) _approvalsButton(context, pending),
          IconButton(
            tooltip: widget.store.isSyncing
                ? 'جارٍ المزامنة...'
                : widget.store.isOnline
                    ? 'مزامنة الآن'
                    : 'غير متصل بالخادم',
            onPressed: widget.store.isSyncing ? null : () => widget.store.refreshFromServer(),
            icon: widget.store.isSyncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(widget.store.isOnline ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded,
                    color: widget.store.isOnline ? null : const Color(0xFFC2414B)),
          ),
          if (widget.store.hasAdminAccess)
            IconButton(
              tooltip: 'إدارة المستخدمين والأدوار',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminScreen(store: widget.store))),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(onPressed: () => _showAbout(context), icon: const Icon(Icons.info_outline_rounded), tooltip: 'حول التطبيق'),
          IconButton(onPressed: widget.store.logout, icon: const Icon(Icons.logout_rounded), tooltip: 'خروج'),
          const SizedBox(width: 5),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => setState(() => selectedIndex = i),
              backgroundColor: Colors.white,
              indicatorColor: teal.withOpacity(.12),
              destinations: tabs.map((t) => NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label)).toList(),
            ),
    );
  }

  Widget _approvalsButton(BuildContext context, int pending) {
    return Stack(children: [
      IconButton(
        tooltip: 'طلبات المتعهدين',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ContractorApprovalsScreen(store: widget.store),
        )),
        icon: const Icon(Icons.assignment_ind_outlined),
      ),
      if (pending > 0)
        Positioned(right: 6, top: 6, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: const Color(0xFFC2414B), borderRadius: BorderRadius.circular(10)),
          constraints: const BoxConstraints(minWidth: 16),
          child: Text('$pending', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
        )),
    ]);
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'تطبيق إدارة الشؤون لأتمتة العمليات',
      applicationVersion: '1.0.0',
      applicationLegalese: 'وحدة إدارة السكن — نسخة تشغيلية',
      children: [Text('يتصل التطبيق بخادم مشترك (${widget.store.baseUrl}) لمزامنة طلبات المتعهدين بين جميع الأجهزة.')],
    );
  }
}
