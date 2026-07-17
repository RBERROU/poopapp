import 'package:flutter/material.dart';
import '../models/fart_recording.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';

/// Ouvre une feuille pour envoyer un pet à un ami. Gère lui-même l'appel réseau
/// et affiche un retour via [onResult].
Future<void> showSendToFriendSheet(
  BuildContext context, {
  required CloudService cloud,
  required FartRecording recording,
  required void Function(String message) onResult,
}) async {
  // Un pet doit être synchronisé (audioUrl) pour pouvoir être envoyé.
  if (!recording.isSynced) {
    onResult('Ce pet se synchronise encore… réessaie dans un instant.');
    return;
  }

  final friends = await cloud.fetchFriends();
  if (!context.mounted) return;

  if (friends.isEmpty) {
    onResult('Ajoute d\'abord un pote (onglet Profil) pour envoyer ! 👋');
    return;
  }

  final chosen = await showModalBottomSheet<Friend>(
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
              child: Text('Envoyer à…',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppTheme.ink)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in friends)
                  ListTile(
                    leading: const Text('🤜', style: TextStyle(fontSize: 22)),
                    title: Text(f.pseudo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: AppTheme.ink)),
                    trailing: const Icon(Icons.send_rounded,
                        color: AppTheme.bubble),
                    onTap: () => Navigator.pop(ctx, f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (chosen == null) return;
  final ok = await cloud.sendFartToFriend(chosen.userId, recording);
  onResult(ok
      ? 'Envoyé à ${chosen.pseudo} ! 💨'
      : 'Échec de l\'envoi, réessaie.');
}
