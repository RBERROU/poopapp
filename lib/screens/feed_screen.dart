import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/feed_item.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

/// Onglet "Le monde" : feed des pets publics des autres utilisateurs.
/// Réactions emoji, signalement et blocage. Position jamais affichée ici
/// (elle vit sur la carte, et de toute façon floutée).
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.cloud});

  /// null si le backend est indisponible (mode 100 % local).
  final CloudService? cloud;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PlayerService _player = PlayerService();
  final ScrollController _scroll = ScrollController();

  List<FeedItem> _items = [];
  Map<String, Set<String>> _myReactions = {};
  bool _loading = true;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _player.onComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cloud = widget.cloud;
    if (cloud == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final items = await cloud.fetchFeed();
    final mine = await cloud.fetchMyReactions([for (final i in items) i.id]);
    if (!mounted) return;
    setState(() {
      _items = items;
      _myReactions = mine;
      _loading = false;
    });
  }

  Future<void> _play(FeedItem item) async {
    if (_playingId == item.id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      await _player.playUrl(item.audioUrl);
      setState(() => _playingId = item.id);
    }
  }

  Future<void> _toggleReaction(FeedItem item, String emoji) async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    final mine = _myReactions[item.id] ?? <String>{};
    final wasOn = mine.contains(emoji);

    // Mise à jour optimiste : l'UI répond tout de suite.
    setState(() {
      final counts = Map<String, int>.from(item.reactions);
      counts[emoji] = (counts[emoji] ?? 0) + (wasOn ? -1 : 1);
      if (counts[emoji]! <= 0) counts.remove(emoji);
      final idx = _items.indexOf(item);
      _items[idx] = _copyWithReactions(item, counts);
      final set = {...mine};
      wasOn ? set.remove(emoji) : set.add(emoji);
      _myReactions[item.id] = set;
    });

    await cloud.toggleReaction(item.id, emoji, currentlyOn: wasOn);
  }

  FeedItem _copyWithReactions(FeedItem i, Map<String, int> reactions) => FeedItem(
        id: i.id,
        userId: i.userId,
        pseudo: i.pseudo,
        name: i.name,
        durationMs: i.durationMs,
        createdAt: i.createdAt,
        latFuzzy: i.latFuzzy,
        lngFuzzy: i.lngFuzzy,
        audioUrl: i.audioUrl,
        reactions: reactions,
      );

  Future<void> _openMenu(FeedItem item) async {
    final action = await showModalBottomSheet<String>(
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
            ListTile(
              leading: const Text('🚩', style: TextStyle(fontSize: 22)),
              title: const Text('Signaler ce pet',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            ListTile(
              leading: const Text('🚫', style: TextStyle(fontSize: 22)),
              title: Text('Bloquer ${item.pseudo}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
          ],
        ),
      ),
    );
    if (action == 'report') {
      await widget.cloud?.reportFart(item.id);
      _snack('Merci, ce pet a été signalé. 🚩');
    } else if (action == 'block') {
      await widget.cloud?.blockUser(item.userId);
      setState(() => _items.removeWhere((i) => i.userId == item.userId));
      _snack('${item.pseudo} est bloqué.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.bubble),
      );
    }
    if (widget.cloud == null) {
      return _empty('🌐', 'Feed indisponible',
          'Connexion au serveur impossible.\nRéessaie plus tard !');
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _empty('🌍', 'Le monde est calme…',
                  'Aucun pet des autres pour l\'instant.\nReviens vite !'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.bubble,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, i) => _FeedCard(
          item: _items[i],
          index: i,
          isPlaying: _playingId == _items[i].id,
          myReactions: _myReactions[_items[i].id] ?? const {},
          onPlay: () => _play(_items[i]),
          onReact: (emoji) => _toggleReaction(_items[i], emoji),
          onMenu: () => _openMenu(_items[i]),
        ),
      ),
    );
  }

  Widget _empty(String emoji, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.item,
    required this.index,
    required this.isPlaying,
    required this.myReactions,
    required this.onPlay,
    required this.onReact,
    required this.onMenu,
  });

  final FeedItem item;
  final int index;
  final bool isPlaying;
  final Set<String> myReactions;
  final VoidCallback onPlay;
  final ValueChanged<String> onReact;
  final VoidCallback onMenu;

  static const _cardColors = [
    Color(0xFFFFE6F2),
    Color(0xFFE4FBF5),
    Color(0xFFFFF4D6),
    Color(0xFFEDE7FF),
  ];
  static const _avatarColors = [
    AppTheme.bubble,
    AppTheme.mint,
    AppTheme.tangerine,
    AppTheme.grape,
  ];

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM · HH:mm').format(item.createdAt);
    final cardColor = _cardColors[index % _cardColors.length];
    final avatarColor = _avatarColors[index % _avatarColors.length];
    final initial =
        item.pseudo.isNotEmpty ? item.pseudo.characters.first.toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.stickerCard(color: cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : avatar pseudo + menu.
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor,
                  border: Border.all(color: AppTheme.ink, width: 3),
                ),
                child: Text(initial,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: avatarColor == AppTheme.mint
                            ? AppTheme.ink
                            : Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.pseudo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: AppTheme.ink)),
                    Text(date,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: AppTheme.ink.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onMenu,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_horiz_rounded, color: AppTheme.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Corps : play + nom + durée.
          Row(
            children: [
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bubble,
                    border: Border.all(color: AppTheme.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: AppTheme.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: AppTheme.ink)),
                    Text(item.durationLabel,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppTheme.ink.withValues(alpha: 0.55))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barre de réactions.
          Row(
            children: [
              for (final emoji in CloudService.reactionEmojis)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ReactionChip(
                    emoji: emoji,
                    count: item.countFor(emoji),
                    active: myReactions.contains(emoji),
                    onTap: () => onReact(emoji),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.zap : Colors.white,
          border: Border.all(color: AppTheme.ink, width: 2.5),
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? const [
                  BoxShadow(
                      color: AppTheme.ink, offset: Offset(2, 2), blurRadius: 0),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text('$count',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: AppTheme.ink)),
            ],
          ],
        ),
      ),
    );
  }
}
