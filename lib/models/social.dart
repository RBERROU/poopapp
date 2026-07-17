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

/// Un pet reçu en privé d'un ami.
class InboxItem {
  final String id;
  final String senderId;
  final String senderPseudo;
  final String name;
  final int durationMs;
  final String audioUrl;
  final DateTime createdAt;
  final bool seen;

  const InboxItem({
    required this.id,
    required this.senderId,
    required this.senderPseudo,
    required this.name,
    required this.durationMs,
    required this.audioUrl,
    required this.createdAt,
    required this.seen,
  });

  String get durationLabel => '${(durationMs / 1000.0).toStringAsFixed(1)} s';
}
