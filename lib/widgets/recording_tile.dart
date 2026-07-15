import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fart_recording.dart';

/// Une ligne de la collection : lecture, nom, date/durée, partage, menu.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.isPlaying,
    required this.onPlay,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  final FartRecording recording;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Format numérique : pas besoin d'initialiser une locale.
    final date = DateFormat('dd/MM/yy · HH:mm').format(recording.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 44,
            onPressed: onPlay,
            icon: Icon(
              isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: scheme.secondary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$date · ${recording.durationLabel}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (recording.hasLocation)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Partager',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'rename') onRename();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renommer')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}
