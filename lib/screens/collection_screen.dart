import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/fart_recording.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';
import '../state/recordings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/recording_tile.dart';
import '../widgets/send_to_friend_sheet.dart';

/// Onglet "Collection" : liste, lecture, envoi privé, partage, renommage, suppression.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.repository, this.cloud});
  final RecordingsRepository repository;
  final CloudService? cloud;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final PlayerService _player = PlayerService();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _player.onComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(FartRecording rec) async {
    if (_playingId == rec.id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      await _player.play(rec);
      setState(() => _playingId = rec.id);
    }
  }

  Future<void> _sendToFriend(FartRecording rec) async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    await showSendToFriendSheet(
      context,
      cloud: cloud,
      recording: rec,
      onResult: _snack,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _share(FartRecording rec) async {
    // Pet présent uniquement au cloud (pas de fichier local) : on partage
    // le lien public plutôt que le fichier.
    if (rec.filePath.isEmpty) {
      final url = rec.audioUrl;
      if (url == null) return;
      await Share.share('${rec.name} — écouté sur Just Fart : $url');
      return;
    }
    await Share.shareXFiles(
      [XFile(rec.filePath)],
      text: '${rec.name} — envoyé depuis Just Fart',
    );
  }

  Future<void> _rename(String id, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.repository.rename(id, name);
    }
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce pet ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.repository.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final items = widget.repository.items;
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💨', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun pet pour l\'instant',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Va dans l\'onglet Enregistrer\npour créer le premier !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final r = items[i];
            return RecordingTile(
              recording: r,
              index: i,
              isPlaying: _playingId == r.id,
              onPlay: () => _play(r),
              onShare: () => _share(r),
              onSendToFriend:
                  widget.cloud == null ? null : () => _sendToFriend(r),
              onRename: () => _rename(r.id, r.name),
              onDelete: () => _confirmDelete(r.id),
            );
          },
        );
      },
    );
  }
}
