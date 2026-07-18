import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';
import '../state/recordings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_picker_sheet.dart';

/// Le fil d'une conversation : les pets échangés, comme un chat.
/// Les miens à droite, ceux des autres à gauche (avec pseudo).
class ConversationThreadScreen extends StatefulWidget {
  const ConversationThreadScreen({
    super.key,
    required this.cloud,
    required this.repository,
    required this.conversationId,
    required this.title,
  });

  final CloudService cloud;
  final RecordingsRepository repository;
  final String conversationId;
  final String title;

  @override
  State<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends State<ConversationThreadScreen> {
  final PlayerService _player = PlayerService();
  final ScrollController _scroll = ScrollController();
  List<Post> _posts = [];
  bool _loading = true;
  bool _sending = false;
  String? _playingId;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = widget.cloud.userId;
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
    final posts = await widget.cloud.fetchPosts(widget.conversationId);
    await widget.cloud.markConversationRead(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _play(Post p) async {
    if (_playingId == p.id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      await _player.playUrl(p.audioUrl);
      setState(() => _playingId = p.id);
    }
  }

  Future<void> _sendPet() async {
    final pet = await showPetPicker(context, widget.repository);
    if (pet == null) return;
    setState(() => _sending = true);
    final ok = await widget.cloud.postFart(widget.conversationId, pet);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      await _load();
    } else {
      _snack('Envoi impossible (le pet se synchronise encore ?).');
    }
  }

  Future<void> _toggleReaction(Post p, String emoji) async {
    final wasOn = p.myReactions.contains(emoji);
    setState(() {
      final counts = Map<String, int>.from(p.reactions);
      counts[emoji] = (counts[emoji] ?? 0) + (wasOn ? -1 : 1);
      if (counts[emoji]! <= 0) counts.remove(emoji);
      final mine = {...p.myReactions};
      wasOn ? mine.remove(emoji) : mine.add(emoji);
      final i = _posts.indexOf(p);
      _posts[i] = p.copyWith(reactions: counts, myReactions: mine);
    });
    await widget.cloud.reactToPost(p.id, emoji, currentlyOn: wasOn);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.cream,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.bubble))
                : _posts.isEmpty
                    ? _empty()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _posts.length,
                        itemBuilder: (context, i) => _bubble(_posts[i]),
                      ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👋', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 14),
              const Text('Lance la conversation !',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink)),
              const SizedBox(height: 6),
              Text('Envoie ton premier pet 💨',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink.withValues(alpha: 0.6))),
            ],
          ),
        ),
      );

  Widget _bubble(Post p) {
    final mine = p.senderId == _myId;
    final playing = _playingId == p.id;
    final time = DateFormat('HH:mm').format(p.createdAt);
    final bubbleColor = mine ? AppTheme.bubble : Colors.white;
    final fg = mine ? Colors.white : AppTheme.ink;

    final content = Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!mine)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 2),
            child: Text(p.senderPseudo,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppTheme.ink)),
          ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: AppTheme.inkBorder,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.hardShadow(dx: mine ? -3 : 3, dy: 3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _play(p),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mine ? Colors.white : AppTheme.bubble,
                    border: Border.all(color: AppTheme.ink, width: 2.5),
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: mine ? AppTheme.bubble : Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: fg)),
                  Text('$time · ${p.durationLabel}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.7))),
                ],
              ),
            ],
          ),
        ),
        _reactionRow(p, mine),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(child: content),
        ],
      ),
    );
  }

  Widget _reactionRow(Post p, bool mine) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 6,
        children: [
          for (final emoji in CloudService.reactionEmojis)
            GestureDetector(
              onTap: () => _toggleReaction(p, emoji),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.myReactions.contains(emoji)
                      ? AppTheme.zap
                      : Colors.white,
                  border: Border.all(color: AppTheme.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    if (p.countFor(emoji) > 0) ...[
                      const SizedBox(width: 3),
                      Text('${p.countFor(emoji)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: AppTheme.ink)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppTheme.paper,
        border: Border(top: BorderSide(color: AppTheme.ink, width: 4)),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _sending ? null : _sendPet,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: AppTheme.stickerCard(
                color: AppTheme.bubble, radius: 999, dx: 3, dy: 3),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Envoyer un pet',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
