import 'package:flutter/material.dart';

/// Thème central de l'app.
/// Un seul endroit pour changer l'identité visuelle de Just Fart.
class AppTheme {
  static const Color primary = Color(0xFF7C4DFF); // violet fun
  static const Color accent = Color(0xFF00E5A0); // vert menthe
  static const Color background = Color(0xFFF5D300);
  static const Color surface = Color(0xFF1F1B2E);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: accent,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
