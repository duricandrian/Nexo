import 'package:flutter/material.dart';

const brandColor = Color(0xFF1B8A5A);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: brandColor, brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: b == Brightness.light ? brandColor : scheme.surface,
      foregroundColor: b == Brightness.light ? Colors.white : scheme.onSurface,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}

Color avatarColor(String seed) {
  const colors = [
    Color(0xFF1B8A5A), Color(0xFF2E7D32), Color(0xFF00838F), Color(0xFF1565C0), Color(0xFF6A1B9A),
    Color(0xFFAD1457), Color(0xFFC62828), Color(0xFFEF6C00), Color(0xFF4E342E), Color(0xFF37474F),
  ];
  return colors[seed.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
}
