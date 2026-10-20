import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// يبني نص CSV متوافقاً مع Excel (BOM + فواصل أسطر CRLF + تهريب الحقول).
String buildCsv(List<String> header, Iterable<List<String>> rows) {
  final buffer = StringBuffer('\uFEFF');
  buffer.write(header.map(_escape).join(','));
  buffer.write('\r\n');
  for (final row in rows) {
    buffer.write(row.map(_escape).join(','));
    buffer.write('\r\n');
  }
  return buffer.toString();
}

String _escape(String value) {
  final v = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
  if (v.contains(',') || v.contains('"') || v.contains(';')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// ينسخ المحتوى للحافظة ويعرض نافذة للتأكيد/النسخ الاحتياطي.
Future<void> copyCsv(BuildContext context, String csv, String title) async {
  await Clipboard.setData(ClipboardData(text: csv));
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(children: const [
        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1F8A70), size: 22),
        SizedBox(width: 8),
        Expanded(child: Text('جاهز للتصدير', style: TextStyle(fontSize: 17))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تم نسخ «$title» بصيغة CSV إلى الحافظة.', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        const Text('الصقه في Excel أو أي محرر جداول (يدعم العربية).', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(10)),
          child: SingleChildScrollView(child: SelectableText(csv, style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        FilledButton.icon(onPressed: () async {
          await Clipboard.setData(ClipboardData(text: csv));
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('نسخ مرة أخرى')),
      ],
    ),
  );
}
