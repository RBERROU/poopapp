import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fart_recording.dart';
import '../theme/app_theme.dart';

/// Une carte "sticker" de la collection : lecture, nom, waveform, date/durée,
/// pin de géoloc, partage et menu. La couleur alterne selon la position.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.index,
    required this.isPlaying,
    required this.onPlay,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  final FartRecording recording;
  final int index;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  // Trio de fonds pastel + couleur du bouton play, en rotation.
  static const _cardColors = [
    Color(0xFFFFE6F2),
    Color(0xFFE4FBF5),
    Color(0xFFFFF4D6),
  ];
  static const _playColors = [AppTheme.bubble, AppTheme.mint, AppTheme.tangerine];

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yy · HH:mm').format(recording.createdAt);
    final cardColor = _cardColors[index % _cardColors.length];
    final playColor = _playColors[index % _playColors.length];
    final playFg = playColor == AppTheme.mint ? AppTheme.ink : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.stickerCard(color: cardColor),
      child: Row(
        children: [
          // Bouton play rond.
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: playColor,
                border: Border.all(color: AppTheme.ink, width: 3),
                boxShadow: const [
                  BoxShadow(
                      color: AppTheme.ink, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: playFg,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppTheme.ink,
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
                          color: AppTheme.ink.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (recording.hasLocation)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('📍', style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                _Waveform(seed: recording.id, active: isPlaying),
              ],
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, color: AppTheme.ink),
            tooltip: 'Partager',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.ink),
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

/// Mini visualisation de waveform. Déterministe (basée sur l'id) pour que
/// chaque pet garde toujours la même silhouette.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.seed, required this.active});
  final String seed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed.hashCode);
    return SizedBox(
      height: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 22; i++) ...[
            Container(
              width: 3,
              height: 4 + rng.nextDouble() * 12,
              decoration: BoxDecoration(
                color: AppTheme.ink.withValues(alpha: active ? 0.9 : 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2.5),
          ],
        ],
      ),
    );
  }
}
