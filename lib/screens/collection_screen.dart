import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/player_service.dart';
import '../state/recordings_repository.dart';
import '../widgets/recording_tile.dart';

/// Onglet "Collection" : liste, lecture, partage, renommage, suppression.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.repository});
  final RecordingsRepository repository;

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

  Future<void> _play(String id, String path) async {
    if (_playingId == id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      await _player.play(path);
      setState(() => _playingId = id);
    }
  }

  Future<void> _share(String path, String name) async {
    await Share.shareXFiles(
      [XFile(path)],
      text: '$name — envoyé depuis Poot',
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                "Aucun pet pour l'instant.\n"
                'Va dans l\'onglet Enregistrer pour créer le premier !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
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
              isPlaying: _playingId == r.id,
              onPlay: () => _play(r.id, r.filePath),
              onShare: () => _share(r.filePath, r.name),
              onRename: () => _rename(r.id, r.name),
              onDelete: () => _confirmDelete(r.id),
            );
          },
        );
      },
    );
  }
}
