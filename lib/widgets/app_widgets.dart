import 'package:flutter/material.dart';

const Color navy = Color(0xFF142A43);
const Color teal = Color(0xFF0D9488);
const Color canvas = Color(0xFFF3F6FA);
const Color muted = Color(0xFF68778A);
const Color line = Color(0xFFE4EAF1);

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: const [BoxShadow(color: Color(0x080E2846), blurRadius: 16, offset: Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: navy)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 12, color: muted)),
        ],
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.caption});
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 21)),
      const SizedBox(height: 12),
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
      if (caption != null) ...[
        const SizedBox(height: 4),
        Text(caption!, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      ],
    ]),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final Color color = switch (label) {
      'متواجد' || 'معتمد' => const Color(0xFF16846B),
      'إجازة' => const Color(0xFF9A6700),
      'خارج السكن' => const Color(0xFF2673B8),
      'غائب' || 'مرفوض' => const Color(0xFFC2414B),
      _ => const Color(0xFF6B7280),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(30)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.subtitle, this.icon = Icons.inbox_outlined});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 42, color: const Color(0xFF9BA8B7)),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(color: navy, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
    ]),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({super.key, required this.label, required this.icon, this.onPressed, this.compact = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: compact ? 17 : 19),
    label: Text(label, style: TextStyle(fontSize: compact ? 12 : 13, fontWeight: FontWeight.w700)),
    style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 10 : 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
  );
}
