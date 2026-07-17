import 'package:flutter/material.dart';

/// Identité visuelle "candy pop / sticker comic" de Just Fart.
/// Monde bonbon assumé : couleurs vives, contours encre épais, ombres dures.
/// Un seul endroit pour changer les couleurs et les recettes de style.
class AppTheme {
  // --- Palette candy ---
  static const Color grape = Color(0xFF6B2FB5); // violet raisin (fond)
  static const Color grapeDeep = Color(0xFF4A1D82);
  static const Color bubble = Color(0xFFFF4FA3); // rose bubble
  static const Color bubbleDeep = Color(0xFFC81E77);
  static const Color zap = Color(0xFFFFD23F); // jaune
  static const Color mint = Color(0xFF2CE5C3); // cyan menthe
  static const Color tangerine = Color(0xFFFF7A3D); // orange
  static const Color ink = Color(0xFF1A0B2E); // encre (contours/texte)
  static const Color cream = Color(0xFFFFF3E6);
  static const Color paper = Color(0xFFFFFBF5);

  /// Épaisseur standard des contours "sticker".
  static const double stroke = 3.5;

  /// Ombre dure décalée façon autocollant (pas de flou).
  static List<BoxShadow> hardShadow({double dx = 5, double dy = 5}) => [
        BoxShadow(color: ink, offset: Offset(dx, dy), blurRadius: 0),
      ];

  /// Bordure encre standard.
  static Border get inkBorder => Border.all(color: ink, width: stroke);

  /// Décoration d'une "carte sticker" : fond + contour + ombre dure.
  static BoxDecoration stickerCard({
    required Color color,
    double radius = 22,
    double dx = 5,
    double dy = 5,
  }) =>
      BoxDecoration(
        color: color,
        border: inkBorder,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hardShadow(dx: dx, dy: dy),
      );

  /// Style du texte display à contour (effet peinture/sticker).
  /// Le contour est peint DERRIÈRE le remplissage (paint order).
  static List<Shadow> get textOutlineShadow =>
      const [Shadow(color: ink, offset: Offset(2.5, 2.5))];

  static Paint outlinePaint(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = ink;

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: bubble,
      brightness: Brightness.light,
    ).copyWith(
      primary: bubble,
      secondary: mint,
      surface: paper,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      fontFamily: 'Trebuchet MS',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Texte display avec contour encre "sticker" (remplissage par-dessus).
class OutlinedDisplayText extends StatelessWidget {
  const OutlinedDisplayText(
    this.text, {
    super.key,
    required this.fontSize,
    this.color = AppTheme.zap,
    this.strokeWidth = 3,
    this.textAlign = TextAlign.center,
    this.dropShadow = true,
  });

  final String text;
  final double fontSize;
  final Color color;
  final double strokeWidth;
  final TextAlign textAlign;
  final bool dropShadow;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.0,
      letterSpacing: -0.5,
    );
    return Stack(
      children: [
        // Contour encre, porteur de l'ombre dure décalée.
        Text(
          text,
          textAlign: textAlign,
          style: base.copyWith(
            foreground: AppTheme.outlinePaint(strokeWidth),
            shadows: dropShadow
                ? const [Shadow(color: AppTheme.ink, offset: Offset(3.5, 4))]
                : null,
          ),
        ),
        // Remplissage coloré par-dessus.
        Text(
          text,
          textAlign: textAlign,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}
