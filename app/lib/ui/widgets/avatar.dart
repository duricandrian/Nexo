import 'package:flutter/material.dart';

import '../../core/theme.dart';

class Avatar extends StatelessWidget {
  final String name;
  final String seed;
  final double radius;
  final bool group;
  const Avatar({super.key, required this.name, required this.seed, this.radius = 22, this.group = false});

  @override
  Widget build(BuildContext context) {
    final clean = name.replaceAll('~', '').trim();
    final parts = clean.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts.first.characters.take(2).toString() : parts.take(2).map((s) => s.characters.first).join())
            .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor(seed),
      child: group
          ? Icon(Icons.group, color: Colors.white, size: radius)
          : Text(initials, style: TextStyle(color: Colors.white, fontSize: radius * 0.75, fontWeight: FontWeight.w600)),
    );
  }
}

/// Threema-style trust level: 1 = key fetched from server, 3 = verified by QR scan.
class VerificationDots extends StatelessWidget {
  final int level;
  const VerificationDots(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = level >= 3 ? Colors.green : (level == 2 ? Colors.orange : Colors.red);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 3; i++)
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: i <= level ? color : Colors.grey.withValues(alpha: 0.3)),
        ),
    ]);
  }
}
