import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';

String formatTime(BuildContext context, int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final locale = Localizations.localeOf(context).toLanguageTag();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return DateFormat.Hm(locale).format(d);
  if (now.difference(d).inDays < 7) return DateFormat.E(locale).format(d);
  return DateFormat.yMd(locale).format(d);
}

String formatDay(BuildContext context, int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return context.l.today;
  if (day == today.subtract(const Duration(days: 1))) return context.l.yesterday;
  return DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag()).format(d);
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

Future<bool> confirm(BuildContext context, String title, String body, {String? action, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l.cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(action ?? context.l.ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, String title, {String initial = '', String? hint, int? maxLength}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: maxLength,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(context.l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(context.l.save)),
      ],
    ),
  );
}

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
