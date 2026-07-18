import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../state/recordings_repository.dart';
import '../theme/app_theme.dart';
import 'conversation_thread_screen.dart';
import 'create_group_screen.dart';

/// Onglet "Conversations" : la liste de tes fils (potes + groupes).
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.cloud,
    required this.repository,
    this.onChanged,
  });

  final CloudService? cloud;
  final RecordingsRepository repository;
  final VoidCallback? onChanged;

  @override
  State<ConversationsScreen> createState() => ConversationsScreenState();
}

class ConversationsScreenState extends State<ConversationsScreen> {
  List<ConversationSummary> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final cloud = widget.cloud;
    if (cloud == null) {
      setState(() => _loading = false);
      return;
    }
    final items = await cloud.fetchConversations();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    widget.onChanged?.call();
  }

  Future<void> _openThread(ConversationSummary c) async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConversationThreadScreen(
        cloud: cloud,
        repository: widget.repository,
        conversationId: c.id,
        title: c.title,
      ),
    ));
    load(); // rafraîchit non-lus / dernier pet au retour
  }

  Future<void> _newConversation() async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    final choice = await showModalBottomSheet<String>(
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
              leading: const Text('👤', style: TextStyle(fontSize: 22)),
              title: const Text('Discuter avec un pote',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(ctx, 'direct'),
            ),
            ListTile(
              leading: const Text('👥', style: TextStyle(fontSize: 22)),
              title: const Text('Créer un groupe',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(ctx, 'group'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'group') {
      await _createGroup();
    } else if (choice == 'direct') {
      await _pickFriendForDirect();
    }
  }

  Future<void> _createGroup() async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateGroupScreen(cloud: cloud)),
    );
    if (created == true) load();
  }

  Future<void> _pickFriendForDirect() async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    final friends = await cloud.fetchFriends();
    if (!mounted) return;
    if (friends.isEmpty) {
      _snack('Ajoute d\'abord un pote (icône profil en haut) ! 👋');
      return;
    }
    final friend = await showModalBottomSheet<Friend>(
      context: context,
      backgroundColor: AppTheme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppTheme.ink, width: AppTheme.stroke),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final f in friends)
              ListTile(
                leading: const Text('🤜', style: TextStyle(fontSize: 22)),
                title: Text(f.pseudo,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (friend == null) return;
    final convId = await cloud.openDirect(friend.userId);
    if (convId == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConversationThreadScreen(
        cloud: cloud,
        repository: widget.repository,
        conversationId: convId,
        title: friend.pseudo,
      ),
    ));
    load();
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
      floatingActionButton: widget.cloud == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _newConversation,
              backgroundColor: AppTheme.bubble,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: AppTheme.ink, width: 3),
              ),
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              label: const Text('Nouveau',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: Colors.white)),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.bubble))
          : _items.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: load,
                  color: AppTheme.bubble,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, i) => _tile(_items[i]),
                  ),
                ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('Aucune conversation',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink)),
              const SizedBox(height: 8),
              Text(
                'Ajoute des potes (icône profil),\npuis lance une conversation avec « Nouveau ».',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );

  Widget _tile(ConversationSummary c) {
    final subtitle = c.lastPostName == null
        ? (c.isGroup ? '${c.memberCount} membres' : 'Dis bonjour 👋')
        : '${c.lastSenderPseudo ?? ''} · ${c.lastPostName}';
    final time = c.lastAt == null ? '' : _shortTime(c.lastAt!);

    return GestureDetector(
      onTap: () => _openThread(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.stickerCard(color: AppTheme.paper),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.isGroup ? AppTheme.mint : AppTheme.bubble,
                border: Border.all(color: AppTheme.ink, width: 3),
              ),
              child: Text(c.isGroup ? '👥' : '👤',
                  style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppTheme.ink.withValues(alpha: 0.55))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(time,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppTheme.ink.withValues(alpha: 0.5))),
                const SizedBox(height: 6),
                if (c.unread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.bubble,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.ink, width: 2),
                    ),
                    child: Text('${c.unread}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortTime(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    return sameDay
        ? DateFormat('HH:mm').format(dt)
        : DateFormat('dd/MM').format(dt);
  }
}
