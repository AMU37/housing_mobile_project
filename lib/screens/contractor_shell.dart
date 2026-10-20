import 'package:flutter/material.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';
import 'contractor_screen.dart';

class ContractorShell extends StatelessWidget {
  const ContractorShell({super.key, required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    final user = store.currentUser;
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF2673B8), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.contractorName.isNotEmpty == true ? user!.contractorName : 'بوابة المتعهد', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: navy)),
            const Text('واجهة المتعهد / المقاول', style: TextStyle(fontSize: 10, color: muted)),
          ])),
        ]),
        actions: [
          IconButton(
            tooltip: store.isSyncing
                ? 'جارٍ المزامنة...'
                : store.isOnline
                    ? 'مزامنة الآن'
                    : 'غير متصل بالخادم',
            onPressed: store.isSyncing ? null : () => store.refreshFromServer(),
            icon: store.isSyncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(store.isOnline ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded,
                    color: store.isOnline ? null : const Color(0xFFC2414B)),
          ),
          IconButton(onPressed: store.logout, icon: const Icon(Icons.logout_rounded), tooltip: 'خروج'),
          const SizedBox(width: 5),
        ],
      ),
      body: ContractorScreen(store: store),
    );
  }
}
