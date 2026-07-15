import 'dart:convert';

/// Un enregistrement de pet, avec ses métadonnées.
/// Le fichier audio lui-même est stocké sur le disque ; ici on ne garde
/// que le chemin + les infos affichées.
class FartRecording {
  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;
  final int durationMs;
  final double? latitude;
  final double? longitude;

  FartRecording({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
    required this.durationMs,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  FartRecording copyWith({String? name}) => FartRecording(
        id: id,
        name: name ?? this.name,
        filePath: filePath,
        createdAt: createdAt,
        durationMs: durationMs,
        latitude: latitude,
        longitude: longitude,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'durationMs': durationMs,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory FartRecording.fromMap(Map<String, dynamic> map) => FartRecording(
        id: map['id'] as String,
        name: map['name'] as String,
        filePath: map['filePath'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        durationMs: (map['durationMs'] as num).toInt(),
        // absentes des anciens enregistrements : null, pas de crash
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
      );

  /// Sérialisation de la liste complète (pour SharedPreferences).
  static String encodeList(List<FartRecording> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<FartRecording> decodeList(String source) =>
      (jsonDecode(source) as List)
          .map((e) => FartRecording.fromMap(e as Map<String, dynamic>))
          .toList();

  /// Durée lisible, ex. "3.2 s".
  String get durationLabel => '${(durationMs / 1000.0).toStringAsFixed(1)} s';
}
