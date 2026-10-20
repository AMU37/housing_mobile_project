import 'package:flutter/material.dart';
import '../models/housing_models.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';

class ContractorApprovalsScreen extends StatelessWidget {
  const ContractorApprovalsScreen({super.key, required this.store});
  final HousingStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final canHousing = store.can('requests.supervise');
        final canSecurity = store.can('requests.security');
        final canVisitor = store.can('requests.visitor');
        final permissions = <String>{
          if (canHousing) 'housing',
          if (canSecurity) 'security',
          if (canVisitor) 'visitor',
        };
        final pending = store.pendingContractorRequests
            .where((r) => permissions.contains(r.stage))
            .toList();
        final history = store.contractorRequests.where((r) => !r.isPending).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final stageNames = <String>[
          if (canHousing) 'السكن',
          if (canSecurity) 'الأمن',
          if (canVisitor) 'الزوار',
        ];
        final title = stageNames.isEmpty
            ? 'طلبات المتعهدين'
            : 'طلبات المتعهدين — ${stageNames.join(' / ')}';
        final hint = 'الموافقة';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: canvas,
            appBar: AppBar(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: navy)),
              actions: [
                IconButton(onPressed: store.logout, icon: const Icon(Icons.logout_rounded), tooltip: 'خروج'),
                const SizedBox(width: 5),
              ],
              bottom: TabBar(
                labelColor: teal,
                unselectedLabelColor: muted,
                indicatorColor: teal,
                tabs: [
                  Tab(text: 'بانتظاري (${pending.length})'),
                  const Tab(text: 'سجل الطلبات'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _list(context, pending, showActions: true, hint: hint,
                    emptyTitle: 'لا توجد طلبات معلقة',
                    emptySubtitle: 'ستظهر هنا طلبات الإضافة والاستبعاد الواردة من المتعهدين'),
                _list(context, history, showActions: false, hint: hint,
                    emptyTitle: 'لا يوجد سجل', emptySubtitle: 'لم تتم معالجة أي طلب بعد'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, List<ContractorRequest> items,
      {required bool showActions, required String hint, required String emptyTitle, required String emptySubtitle}) {
    if (items.isEmpty) {
      return AppCard(margin: const EdgeInsets.all(16), child: EmptyState(title: emptyTitle, subtitle: emptySubtitle, icon: Icons.assignment_turned_in_outlined));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showActions) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: teal.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.fact_check_rounded, color: teal, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('${items.length} طلب بانتظار $hint', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy))),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        ...items.map((r) => _card(context, r, showActions: showActions)),
      ],
    );
  }

  Widget _card(BuildContext context, ContractorRequest r, {required bool showActions}) {
    final color = r.isRejected ? const Color(0xFFC2414B) : (r.isDone ? const Color(0xFF16846B) : const Color(0xFF9A6700));
    final contractor = store.contractorById(r.contractorId);
    final free = store.freeBedCountForContractor(r.contractorId);
    final buildingNames = store.buildingsForContractor(r.contractorId).map((b) => b.name).join(' • ');
    final canApprove = r.isAdd ? free > 0 : true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(r.isAdd ? Icons.person_add_alt_1_rounded : Icons.person_remove_alt_1_rounded, size: 20, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.typeLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: navy)),
              Text('${r.contractorName}${contractor == null ? '' : ' • ${contractor.typeLabel}'}', style: const TextStyle(fontSize: 11, color: muted)),
            ])),
            StatusPill(r.stageLabel),
          ]),
          const SizedBox(height: 12),
          _row('العامل', r.workerName.isEmpty ? 'بدون اسم' : r.workerName),
          if (r.workerCardNumber.isNotEmpty) _row('رقم البطاقة', r.workerCardNumber),
          if (r.workerBirthDate != null) _row('تاريخ الميلاد', r.workerBirthDateLabel),
          if (r.workerAge != null) _row('العمر', '${r.workerAge} سنة', valueColor: (r.workerAge ?? 0) < 18 ? const Color(0xFFC2414B) : const Color(0xFF16846B)),
          if (r.workerBirthPlace.isNotEmpty) _row('مكان الميلاد', r.workerBirthPlace),
          if (r.employeeCode.isNotEmpty) _row('كود الموظف', r.employeeCode),
          if (r.jobTitle.isNotEmpty) _row('المسمى', r.jobTitle),
          if (buildingNames.isNotEmpty) _row('السكن', buildingNames),
          if (r.isAdd) _row('الأسرّة المتاحة', '$free سرير', valueColor: canApprove ? const Color(0xFF16846B) : const Color(0xFFC2414B)),
          if (r.reason.isNotEmpty) _row('السبب', r.reason),
          if (r.housingApprover.isNotEmpty) _row('مراقب السكن', r.housingApprover),
          if (r.securityApprover.isNotEmpty) _row('مشرف الأمن', r.securityApprover),
          if (r.visitorApprover.isNotEmpty) _row('مراقب الزوار', r.visitorApprover),
          if (r.reviewNotes.isNotEmpty) _row('ملاحظة', r.reviewNotes),
          if (showActions && r.isPending) ...[
            const SizedBox(height: 12),
            if (r.isAdd && !canApprove && (r.awaitingVisitor || r.awaitingHousing)) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: const Color(0xFFC2414B).withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC2414B)),
                  SizedBox(width: 8),
                  Expanded(child: Text('لا يوجد سرير متاح لدى المتعهد — لا يمكن تنفيذ الإضافة.', style: TextStyle(fontSize: 11, color: Color(0xFFC2414B), fontWeight: FontWeight.w700))),
                ]),
              ),
            ],
            Row(children: [
              Expanded(child: PrimaryAction(
                label: _actionLabel(r),
                icon: _actionIcon(r),
                compact: true,
                onPressed: () => _approve(context, r),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final err = await store.rejectContractorRequest(r.id,
                      reviewNotes: 'مرفوض من ${_stageActorName(r.stage)}');
                  if (err != null) {
                    messenger.showSnackBar(SnackBar(content: Text(err), backgroundColor: const Color(0xFFC2414B)));
                  } else {
                    messenger.showSnackBar(const SnackBar(content: Text('تم رفض الطلب'), backgroundColor: Color(0xFFC2414B)));
                  }
                },
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('رفض', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC2414B), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), side: const BorderSide(color: Color(0xFFE7B7BB))),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  String _stageActorName(String stage) {
    switch (stage) {
      case 'housing':
        return 'مراقب السكن';
      case 'security':
        return 'مشرف الأمن';
      case 'visitor':
        return 'مراقب الزوار';
      default:
        return 'المراجع';
    }
  }

  bool _isExecutionStage(ContractorRequest r) =>
      r.isAdd ? r.awaitingHousing : r.awaitingVisitor;

  String _actionLabel(ContractorRequest r) {
    if (_isExecutionStage(r)) {
      return r.isAdd ? 'موافقة نهائية وتنفيذ التسكين' : 'موافقة نهائية وتنفيذ الاستبعاد';
    }
    switch (r.stage) {
      case 'security':
        return 'موافقة أمنية وإحالة للزوار';
      case 'visitor':
        return 'تسجيل كود الموظف وإحالة للسكن';
      case 'housing':
        return 'موافقة وإحالة للأمن';
      default:
        return 'موافقة';
    }
  }

  IconData _actionIcon(ContractorRequest r) {
    if (_isExecutionStage(r)) return Icons.verified_user_rounded;
    switch (r.stage) {
      case 'security':
        return Icons.security_rounded;
      case 'visitor':
        return Icons.badge_rounded;
      default:
        return Icons.forward_to_inbox_rounded;
    }
  }

  Future<void> _approve(BuildContext context, ContractorRequest r) async {
    final messenger = ScaffoldMessenger.of(context);
    String employeeCode = '';
    // مراقب الزوار في طلب الإضافة يدخل كود الموظف إجبارياً.
    if (r.awaitingVisitor && r.isAdd) {
      final code = await _promptEmployeeCode(context, r);
      if (code == null) return;
      employeeCode = code;
    }
    String? err;
    if (r.awaitingSecurity) {
      err = await store.approveSecurityStage(r.id);
    } else if (r.awaitingVisitor) {
      err = await store.approveVisitorStage(r.id, employeeCode: employeeCode);
    } else {
      err = await store.approveHousingStage(r.id);
    }
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err), backgroundColor: const Color(0xFFC2414B)));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(_isExecutionStage(r) ? 'تم اعتماد الطلب وتنفيذه' : 'تمت الموافقة وإحالة الطلب للمرحلة التالية'),
        backgroundColor: const Color(0xFF16846B),
      ));
    }
  }

  Future<String?> _promptEmployeeCode(BuildContext context, ContractorRequest r) async {
    final controller = TextEditingController(text: r.employeeCode);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كود الموظف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العامل: ${r.workerName}', style: const TextStyle(fontSize: 12, color: muted)),
            if (r.workerAge != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('العمر: ${r.workerAge} سنة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: (r.workerAge ?? 0) < 18 ? const Color(0xFFC2414B) : const Color(0xFF16846B))),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'كود الموظف (إجباري)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx, code);
            },
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
    return result;
  }

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: valueColor ?? navy, fontWeight: FontWeight.w700))),
    ]),
  );
}
