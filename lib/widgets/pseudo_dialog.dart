import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Dialog d'édition du pseudo affiché dans le feed public.
/// Renvoie le nouveau pseudo (trimé) ou null si annulé.
Future<String?> showPseudoDialog(
  BuildContext context, {
  required String current,
}) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.ink, width: AppTheme.stroke),
      ),
      title: const Text('Ton pseudo',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.ink)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [LengthLimitingTextInputFormatter(24)],
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
        decoration: InputDecoration(
          hintText: 'Ex : Le Baron du Pet',
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.ink, width: 2.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.bubble, width: 3),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(ctx, controller.text.trim()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: AppTheme.stickerCard(
                color: AppTheme.bubble, radius: 999, dx: 2, dy: 2),
            child: const Text('Enregistrer',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
      ],
    ),
  );
}
