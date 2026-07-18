import 'package:flutter/material.dart';
import '../models/fart_recording.dart';
import '../state/recordings_repository.dart';
import '../theme/app_theme.dart';

/// Feuille de sélection d'un pet de sa collection (pour l'envoyer).
/// Ne propose que les pets synchronisés (partageables). Renvoie le pet choisi.
Future<FartRecording?> showPetPicker(
  BuildContext context,
  RecordingsRepository repository,
) {
  final pets = repository.items.where((p) => p.isSynced).toList();
  return showModalBottomSheet<FartRecording>(
    context: context,
    backgroundColor: AppTheme.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: AppTheme.ink, width: AppTheme.stroke),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Choisis un pet à envoyer',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppTheme.ink)),
            ),
          ),
          if (pets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Aucun pet prêt à envoyer.\nEnregistre-en un d\'abord ! 🎙️',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink.withValues(alpha: 0.6)),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in pets)
                    ListTile(
                      leading: const Text('💨', style: TextStyle(fontSize: 22)),
                      title: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink)),
                      subtitle: Text(p.durationLabel,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink.withValues(alpha: 0.55))),
                      trailing:
                          const Icon(Icons.send_rounded, color: AppTheme.bubble),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
