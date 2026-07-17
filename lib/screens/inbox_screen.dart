import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

/// Onglet "Reçus" : les pets qu'on t'a envoyés en privé.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.cloud, this.onChanged});
  final CloudService? cloud;

  /// Appelé quand le nombre de non-lus change (pour rafraîchir le badge).
  final VoidCallback? onChanged;

  @override
  State<InboxScreen> createState() => InboxScreenState();
}

class InboxScreenState extends State<InboxScreen> {
  final PlayerService _player = PlayerService();
  List<InboxItem> _items = [];
  bool _loading = true;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _player.onComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
    load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Public : permet au parent de recharger quand on ouvre l'onglet.
  Future<void> load() async {
    final cloud = widget.cloud;
    if (cloud == null) {
      setState(() => _loading = false);
      return;
    }
    final items = await cloud.fetchInbox();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _play(InboxItem item) async {
    if (_playingId == item.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    await _player.playUrl(item.audioUrl);
    setState(() => _playingId = item.id);
    if (!item.seen) {
      await widget.cloud?.markSeen(item.id);
      final i = _items.indexOf(item);
      setState(() => _items[i] = _seenCopy(item));
      widget.onChanged?.call();
    }
  }

  InboxItem _seenCopy(InboxItem i) => InboxItem(
        id: i.id,
        senderId: i.senderId,
        senderPseudo: i.senderPseudo,
        name: i.name,
        durationMs: i.durationMs,
        audioUrl: i.audioUrl,
        createdAt: i.createdAt,
        seen: true,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.bubble));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        color: AppTheme.bubble,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📭', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      const Text('Aucun pet reçu',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink)),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoute des potes et demande-leur\nde t\'envoyer leurs meilleurs pets !',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      color: AppTheme.bubble,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, i) => _tile(_items[i], i),
      ),
    );
  }

  Widget _tile(InboxItem item, int index) {
    final date = DateFormat('dd/MM · HH:mm').format(item.createdAt);
    final playing = _playingId == item.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.stickerCard(
        color: item.seen ? AppTheme.paper : const Color(0xFFFFE6F2),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _play(item),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bubble,
                border: Border.all(color: AppTheme.ink, width: 3),
                boxShadow: const [
                  BoxShadow(
                      color: AppTheme.ink, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!item.seen)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.bubble,
                        ),
                      ),
                    Flexible(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppTheme.ink)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('de ${item.senderPseudo} · $date · ${item.durationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.ink.withValues(alpha: 0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
