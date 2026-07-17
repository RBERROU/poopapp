/// Un pet du feed public (posté par un autre utilisateur).
/// Vient de la vue Supabase `public_feed` : position floutée, pseudo,
/// compteurs de réactions agrégés.
class FeedItem {
  final String id;
  final String userId;
  final String pseudo;
  final String name;
  final int durationMs;
  final DateTime createdAt;
  final double? latFuzzy;
  final double? lngFuzzy;
  final String audioUrl;
  final Map<String, int> reactions;

  const FeedItem({
    required this.id,
    required this.userId,
    required this.pseudo,
    required this.name,
    required this.durationMs,
    required this.createdAt,
    required this.audioUrl,
    required this.reactions,
    this.latFuzzy,
    this.lngFuzzy,
  });

  bool get hasLocation => latFuzzy != null && lngFuzzy != null;

  String get durationLabel => '${(durationMs / 1000.0).toStringAsFixed(1)} s';

  int countFor(String emoji) => reactions[emoji] ?? 0;

  factory FeedItem.fromRow(
    Map<String, dynamic> row, {
    required String audioUrl,
  }) {
    final rawReactions = (row['reactions'] as Map?) ?? const {};
    return FeedItem(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      pseudo: (row['pseudo'] as String?) ?? 'Péteur anonyme',
      name: row['name'] as String,
      durationMs: (row['duration_ms'] as num).toInt(),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      latFuzzy: (row['lat_fuzzy'] as num?)?.toDouble(),
      lngFuzzy: (row['lng_fuzzy'] as num?)?.toDouble(),
      audioUrl: audioUrl,
      reactions: rawReactions.map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
    );
  }
}
