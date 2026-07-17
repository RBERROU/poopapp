import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fart_recording.dart';
import '../models/feed_item.dart';
import '../models/social.dart';

/// Accès au backend Supabase : upload des fichiers audio vers le bucket
/// `farts` et métadonnées dans la table `farts`.
/// Toutes les méthodes échouent en silence (log + null/no-op) : le cloud
/// est une couche de synchronisation, jamais un point de blocage de l'app.
class CloudService {
  CloudService(this._client);
  final SupabaseClient _client;

  static const _bucket = 'farts';

  /// Emojis de réaction disponibles, dans l'ordre d'affichage.
  static const reactionEmojis = ['💨', '🔥', '😂', '🤢'];

  String? get userId => _client.auth.currentUser?.id;

  String publicUrlFor(String audioPath) =>
      _client.storage.from(_bucket).getPublicUrl(audioPath);

  /// Chemin de stockage ({uid}/{id}.ext) déduit d'une URL publique, ou null.
  String? storagePathFromUrl(String url) {
    const marker = '/object/public/$_bucket/';
    final i = url.indexOf(marker);
    if (i == -1) return null;
    return Uri.decodeComponent(url.substring(i + marker.length));
  }

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
        final path = storagePathFromUrl(url);
        if (path != null) {
          await _client.storage.from(_bucket).remove([path]);
        }
      }
    } catch (e) {
      debugPrint('Suppression cloud ${rec.id} impossible : $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Social : feed public, réactions, modération, pseudo.
  // ---------------------------------------------------------------------------

  /// Récupère le feed public (pets des autres), le plus récent d'abord.
  /// Position floutée, utilisateurs bloqués et mes propres pets exclus côté SQL.
  Future<List<FeedItem>> fetchFeed({int limit = 100}) async {
    try {
      final rows = await _client
          .from('public_feed')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final row in List<Map<String, dynamic>>.from(rows))
          FeedItem.fromRow(
            row,
            audioUrl: publicUrlFor(row['audio_path'] as String),
          ),
      ];
    } catch (e) {
      debugPrint('Chargement du feed impossible : $e');
      return [];
    }
  }

  /// Emojis que l'utilisateur courant a posés sur ces pets : { fartId: {emoji} }.
  Future<Map<String, Set<String>>> fetchMyReactions(
      List<String> fartIds) async {
    final uid = userId;
    if (uid == null || fartIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('reactions')
          .select('fart_id, emoji')
          .eq('user_id', uid)
          .inFilter('fart_id', fartIds);
      final result = <String, Set<String>>{};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        (result[row['fart_id'] as String] ??= {}).add(row['emoji'] as String);
      }
      return result;
    } catch (e) {
      debugPrint('Chargement de mes réactions impossible : $e');
      return {};
    }
  }

  /// Ajoute ou retire une réaction. Renvoie true si elle est active après coup.
  Future<bool> toggleReaction(String fartId, String emoji,
      {required bool currentlyOn}) async {
    final uid = userId;
    if (uid == null) return currentlyOn;
    try {
      if (currentlyOn) {
        await _client
            .from('reactions')
            .delete()
            .eq('fart_id', fartId)
            .eq('user_id', uid)
            .eq('emoji', emoji);
        return false;
      } else {
        await _client.from('reactions').insert({
          'fart_id': fartId,
          'user_id': uid,
          'emoji': emoji,
        });
        return true;
      }
    } catch (e) {
      debugPrint('Réaction impossible : $e');
      return currentlyOn;
    }
  }

  Future<void> reportFart(String fartId, {String? reason}) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await _client.from('reports').insert({
        'reporter_id': uid,
        'fart_id': fartId,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('Signalement impossible : $e');
    }
  }

  Future<void> blockUser(String blockedId) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await _client.from('blocks').insert({
        'blocker_id': uid,
        'blocked_id': blockedId,
      });
    } catch (e) {
      debugPrint('Blocage impossible : $e');
    }
  }

  Future<String?> fetchMyPseudo() async {
    final uid = userId;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('pseudo')
          .eq('id', uid)
          .maybeSingle();
      return row?['pseudo'] as String?;
    } catch (e) {
      debugPrint('Lecture du pseudo impossible : $e');
      return null;
    }
  }

  Future<void> updatePseudo(String pseudo) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await _client.from('profiles').update({'pseudo': pseudo}).eq('id', uid);
    } catch (e) {
      debugPrint('Mise à jour du pseudo impossible : $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Amis : code, demandes, liste.
  // ---------------------------------------------------------------------------

  /// Mon profil : { pseudo, friend_code }.
  Future<({String pseudo, String code})?> fetchMyProfile() async {
    final uid = userId;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('pseudo, friend_code')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return null;
      return (
        pseudo: (row['pseudo'] as String?) ?? 'Péteur anonyme',
        code: (row['friend_code'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('Lecture de mon profil impossible : $e');
      return null;
    }
  }

  /// Cherche un utilisateur par son code ami. Renvoie (id, pseudo) ou null.
  Future<({String id, String pseudo})?> findByCode(String code) async {
    try {
      final row = await _client
          .from('profiles')
          .select('id, pseudo')
          .eq('friend_code', code.trim().toUpperCase())
          .maybeSingle();
      if (row == null) return null;
      return (id: row['id'] as String, pseudo: row['pseudo'] as String);
    } catch (e) {
      debugPrint('Recherche par code impossible : $e');
      return null;
    }
  }

  /// Envoie une demande d'ami. Renvoie un message d'état pour l'UI.
  Future<String> sendFriendRequest(String targetId) async {
    final uid = userId;
    if (uid == null) return 'Connexion requise.';
    if (targetId == uid) return 'C\'est toi, ça ! 😅';
    try {
      await _client.from('friendships').insert({
        'requester_id': uid,
        'addressee_id': targetId,
      });
      return 'Demande envoyée ! 🤝';
    } on PostgrestException catch (e) {
      // 23505 = doublon (relation déjà existante dans ce sens).
      if (e.code == '23505') return 'Demande déjà envoyée.';
      debugPrint('Demande d\'ami impossible : $e');
      return 'Impossible d\'envoyer la demande.';
    } catch (e) {
      debugPrint('Demande d\'ami impossible : $e');
      return 'Impossible d\'envoyer la demande.';
    }
  }

  /// Demandes d'amis reçues (en attente).
  Future<List<FriendRequest>> fetchIncomingRequests() async {
    final uid = userId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('friendships')
          .select('id, requester_id')
          .eq('addressee_id', uid)
          .eq('status', 'pending');
      final list = List<Map<String, dynamic>>.from(rows);
      final pseudos =
          await _pseudosFor([for (final r in list) r['requester_id'] as String]);
      return [
        for (final r in list)
          FriendRequest(
            friendshipId: r['id'] as String,
            userId: r['requester_id'] as String,
            pseudo: pseudos[r['requester_id']] ?? 'Péteur anonyme',
          ),
      ];
    } catch (e) {
      debugPrint('Chargement des demandes impossible : $e');
      return [];
    }
  }

  Future<void> respondToRequest(String friendshipId, {required bool accept}) async {
    try {
      if (accept) {
        await _client
            .from('friendships')
            .update({'status': 'accepted'}).eq('id', friendshipId);
      } else {
        await _client.from('friendships').delete().eq('id', friendshipId);
      }
    } catch (e) {
      debugPrint('Réponse à la demande impossible : $e');
    }
  }

  /// Liste des amis acceptés (dans les deux sens).
  Future<List<Friend>> fetchFriends() async {
    final uid = userId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('friendships')
          .select('requester_id, addressee_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid');
      final list = List<Map<String, dynamic>>.from(rows);
      final otherIds = [
        for (final r in list)
          (r['requester_id'] as String) == uid
              ? r['addressee_id'] as String
              : r['requester_id'] as String,
      ];
      final pseudos = await _pseudosFor(otherIds);
      return [
        for (final id in otherIds)
          Friend(userId: id, pseudo: pseudos[id] ?? 'Péteur anonyme'),
      ];
    } catch (e) {
      debugPrint('Chargement des amis impossible : $e');
      return [];
    }
  }

  Future<Map<String, String>> _pseudosFor(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('profiles')
        .select('id, pseudo')
        .inFilter('id', ids);
    return {
      for (final r in List<Map<String, dynamic>>.from(rows))
        r['id'] as String: (r['pseudo'] as String?) ?? 'Péteur anonyme',
    };
  }

  // ---------------------------------------------------------------------------
  // Envois privés (DM) + boîte de réception.
  // ---------------------------------------------------------------------------

  /// Envoie un pet en privé à un ami. Renvoie true si envoyé.
  Future<bool> sendFartToFriend(String recipientId, FartRecording rec) async {
    final uid = userId;
    if (uid == null) return false;
    final url = rec.audioUrl;
    final path = url == null ? null : storagePathFromUrl(url);
    if (path == null) return false; // pas encore synchronisé sur le cloud
    try {
      await _client.from('direct_sends').insert({
        'sender_id': uid,
        'recipient_id': recipientId,
        'fart_id': rec.id,
        'name': rec.name,
        'duration_ms': rec.durationMs,
        'audio_path': path,
      });
      return true;
    } catch (e) {
      debugPrint('Envoi privé impossible : $e');
      return false;
    }
  }

  /// Pets reçus (les plus récents d'abord).
  Future<List<InboxItem>> fetchInbox() async {
    final uid = userId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('direct_sends')
          .select()
          .eq('recipient_id', uid)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rows);
      final pseudos =
          await _pseudosFor([for (final r in list) r['sender_id'] as String]);
      return [
        for (final r in list)
          InboxItem(
            id: r['id'] as String,
            senderId: r['sender_id'] as String,
            senderPseudo: pseudos[r['sender_id']] ?? 'Péteur anonyme',
            name: r['name'] as String,
            durationMs: (r['duration_ms'] as num).toInt(),
            audioUrl: publicUrlFor(r['audio_path'] as String),
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            seen: r['seen_at'] != null,
          ),
      ];
    } catch (e) {
      debugPrint('Chargement de la boîte de réception impossible : $e');
      return [];
    }
  }

  /// Nombre de pets reçus non lus (pour le badge de nav).
  Future<int> countUnseen() async {
    final uid = userId;
    if (uid == null) return 0;
    try {
      final rows = await _client
          .from('direct_sends')
          .select('id')
          .eq('recipient_id', uid)
          .isFilter('seen_at', null);
      return List.from(rows).length;
    } catch (e) {
      debugPrint('Comptage des non-lus impossible : $e');
      return 0;
    }
  }

  Future<void> markSeen(String sendId) async {
    try {
      await _client
          .from('direct_sends')
          .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', sendId);
    } catch (e) {
      debugPrint('Marquage lu impossible : $e');
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
