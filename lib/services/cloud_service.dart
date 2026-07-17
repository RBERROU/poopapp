import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fart_recording.dart';

/// Accès au backend Supabase : upload des fichiers audio vers le bucket
/// `farts` et métadonnées dans la table `farts`.
/// Toutes les méthodes échouent en silence (log + null/no-op) : le cloud
/// est une couche de synchronisation, jamais un point de blocage de l'app.
class CloudService {
  CloudService(this._client);
  final SupabaseClient _client;

  static const _bucket = 'farts';

  String? get userId => _client.auth.currentUser?.id;

  String publicUrlFor(String audioPath) =>
      _client.storage.from(_bucket).getPublicUrl(audioPath);

  /// Upload l'audio + la ligne de métadonnées. Renvoie l'URL publique,
  /// ou null si l'upload a échoué (offline, fichier disparu…).
  Future<String?> uploadFart(FartRecording rec) async {
    final uid = userId;
    if (uid == null) return null;
    try {
      final data = await _readAudio(rec.filePath);
      if (data == null) return null;

      final ext = data.extension;
      final storagePath = '$uid/${rec.id}.$ext';
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            data.bytes,
            fileOptions: FileOptions(
              contentType: data.contentType,
              upsert: true,
            ),
          );
      await _client.from('farts').upsert({
        'id': rec.id,
        'user_id': uid,
        'name': rec.name,
        'duration_ms': rec.durationMs,
        'created_at': rec.createdAt.toUtc().toIso8601String(),
        'latitude': rec.latitude,
        'longitude': rec.longitude,
        'audio_path': storagePath,
        'format': ext,
      });
      return publicUrlFor(storagePath);
    } catch (e) {
      debugPrint('Upload pet ${rec.id} impossible : $e');
      return null;
    }
  }

  /// Tous les pets de l'utilisateur courant (les plus récents d'abord).
  Future<List<Map<String, dynamic>>> fetchMyFarts() async {
    final uid = userId;
    if (uid == null) return [];
    final rows = await _client
        .from('farts')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> renameFart(String id, String name) async {
    try {
      await _client.from('farts').update({'name': name}).eq('id', id);
    } catch (e) {
      debugPrint('Renommage cloud $id impossible : $e');
    }
  }

  Future<void> deleteFart(FartRecording rec) async {
    try {
      await _client.from('farts').delete().eq('id', rec.id);
      final url = rec.audioUrl;
      if (url != null) {
        const marker = '/object/public/$_bucket/';
        final i = url.indexOf(marker);
        if (i != -1) {
          final path = Uri.decodeComponent(url.substring(i + marker.length));
          await _client.storage.from(_bucket).remove([path]);
        }
      }
    } catch (e) {
      debugPrint('Suppression cloud ${rec.id} impossible : $e');
    }
  }

  /// Lit les octets de l'audio. Natif : fichier disque (toujours du m4a).
  /// Web : fetch de la blob URL, format déterminé par le navigateur
  /// (webm sur Chrome, mp4 sur Safari).
  Future<({Uint8List bytes, String contentType, String extension})?>
      _readAudio(String path) async {
    if (path.isEmpty) return null;
    if (kIsWeb) {
      final res = await http.get(Uri.parse(path));
      if (res.statusCode != 200) return null;
      final mime = res.headers['content-type'] ?? 'audio/webm';
      final ext = mime.contains('webm')
          ? 'webm'
          : mime.contains('ogg')
              ? 'ogg'
              : 'm4a';
      return (
        bytes: res.bodyBytes,
        contentType: mime.split(';').first,
        extension: ext,
      );
    }
    final file = File(path);
    if (!await file.exists()) return null;
    return (
      bytes: await file.readAsBytes(),
      contentType: 'audio/mp4',
      extension: 'm4a',
    );
  }
}
