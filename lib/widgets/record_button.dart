import 'package:flutter/material.dart';

/// Gros bouton central d'enregistrement.
/// Change de couleur et de forme selon l'état (prêt / en cours).
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: isRecording ? 180 : 200,
        height: isRecording ? 180 : 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isRecording
                ? [Colors.redAccent, Colors.deepOrange]
                : [scheme.primary, scheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.redAccent : scheme.primary)
                  .withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          size: 80,
          color: Colors.white,
        ),
      ),
    );
  }
}
