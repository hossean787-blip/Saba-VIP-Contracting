import 'package:flutter/material.dart';
import '../core/theme.dart';

class VipCard extends StatelessWidget {
  const VipCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF334454), width: .7),
        ),
        child: child,
      );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ivory))),
    if (trailing != null) trailing!,
  ]);
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, required this.subtitle, this.icon = Icons.inbox_outlined});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => VipCard(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 18), Icon(icon, color: champagne, size: 48), const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
      const SizedBox(height: 18),
    ]),
  );
}

void showFeedback(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? const Color(0xFF9C4B4B) : panelLight));
}
