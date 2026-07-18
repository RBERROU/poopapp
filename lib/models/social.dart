/// Un ami accepté.
class Friend {
  final String userId;
  final String pseudo;
  const Friend({required this.userId, required this.pseudo});
}

/// Une demande d'ami reçue (en attente d'acceptation).
class FriendRequest {
  final String friendshipId;
  final String userId;
  final String pseudo;
  const FriendRequest({
    required this.friendshipId,
    required this.userId,
    required this.pseudo,
  });
}

/// Résumé d'une conversation dans la liste (fil direct ou groupe).
class ConversationSummary {
  final String id;
  final String kind; // 'direct' | 'group'
  final String title;
  final String? lastPostName;
  final String? lastSenderPseudo;
  final DateTime? lastAt;
  final int unread;
  final int memberCount;

  const ConversationSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.unread,
    required this.memberCount,
    this.lastPostName,
    this.lastSenderPseudo,
    this.lastAt,
  });

  bool get isGroup => kind == 'group';

  factory ConversationSummary.fromRow(Map<String, dynamic> row) =>
      ConversationSummary(
        id: row['id'] as String,
        kind: row['kind'] as String,
        title: (row['title'] as String?) ?? 'Conversation',
        lastPostName: row['last_post_name'] as String?,
        lastSenderPseudo: row['last_sender_pseudo'] as String?,
        lastAt: row['last_at'] == null
            ? null
            : DateTime.parse(row['last_at'] as String).toLocal(),
        unread: (row['unread'] as num?)?.toInt() ?? 0,
        memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      );
}

/// Un pet partagé dans une conversation.
class Post {
  final String id;
  final String senderId;
  final String senderPseudo;
  final String name;
  final int durationMs;
  final String audioUrl;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final Map<String, int> reactions;
  final Set<String> myReactions;

  Post({
    required this.id,
    required this.senderId,
    required this.senderPseudo,
    required this.name,
    required this.durationMs,
    required this.audioUrl,
    required this.createdAt,
    required this.reactions,
    required this.myReactions,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;
  String get durationLabel => '${(durationMs / 1000.0).toStringAsFixed(1)} s';
  int countFor(String emoji) => reactions[emoji] ?? 0;

  Post copyWith({Map<String, int>? reactions, Set<String>? myReactions}) => Post(
        id: id,
        senderId: senderId,
        senderPseudo: senderPseudo,
        name: name,
        durationMs: durationMs,
        audioUrl: audioUrl,
        createdAt: createdAt,
        latitude: latitude,
        longitude: longitude,
        reactions: reactions ?? this.reactions,
        myReactions: myReactions ?? this.myReactions,
      );
}
