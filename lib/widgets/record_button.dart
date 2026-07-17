import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Gros bouton central d'enregistrement, héros de l'écran.
/// Au repos : flotte doucement (bob) avec un anneau pointillé qui tourne.
/// En cours : passe au rouge, se resserre, l'anneau accélère.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  final bool isRecording;
  final VoidCallback onTap;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))
        ..repeat();

  @override
  void dispose() {
    _bob.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.isRecording;
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: Listenable.merge([_bob, _ring]),
          builder: (context, child) {
            final bob = math.sin(_bob.value * math.pi) * 8;
            return Transform.translate(
              offset: Offset(0, recording ? 0 : -bob),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anneau pointillé rotatif.
                  Transform.rotate(
                    angle: _ring.value * 2 * math.pi * (recording ? 3 : 1),
                    child: CustomPaint(
                      size: const Size(206, 206),
                      painter: _DashedRingPainter(),
                    ),
                  ),
                  child!,
                ],
              ),
            );
          },
          child: _ButtonBody(recording: recording),
        ),
      ),
    );
  }
}

class _ButtonBody extends StatelessWidget {
  const _ButtonBody({required this.recording});
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: recording ? 150 : 168,
      height: recording ? 150 : 168,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: recording
              ? const [Color(0xFFFF6B6B), AppTheme.bubbleDeep]
              : const [AppTheme.zap, AppTheme.tangerine],
        ),
        border: Border.all(color: AppTheme.ink, width: 6),
        boxShadow: const [
          BoxShadow(color: AppTheme.ink, offset: Offset(0, 8), blurRadius: 0),
        ],
      ),
      child: Center(
        child: recording
            ? const Icon(Icons.stop_rounded, size: 66, color: Colors.white)
            : const Text('💨', style: TextStyle(fontSize: 62)),
      ),
    );
  }
}

/// Anneau en pointillés (tirets) façon maquette.
class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.ink.withValues(alpha: 0.55);

    const dashes = 30;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      final start = i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => false;
}
