import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fart_recording.dart';
import '../models/social.dart';

/// Accès au backend Supabase.
/// - Sauvegarde perso : bucket audio + table `farts` (privée au propriétaire).
/// - Social communautaire : amis, conversations (fils privés / groupes), posts.
/// Toutes les méthodes échouent en silence (log + null/no-op) : le cloud ne
/// bloque jamais l'app, qui reste utilisable en local.
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

  // ---------------------------------------------------------------------------
  // Collection perso (backup cloud).
  // ---------------------------------------------------------------------------

  /// Upload l'audio + la ligne de métadonnées. Renvoie l'URL publique, ou null.
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
            fileOptions: FileOptions(contentType: data.contentType, upsert: true),
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
        if (path != null) await _client.storage.from(_bucket).remove([path]);
      }
    } catch (e) {
      debugPrint('Suppression cloud ${rec.id} impossible : $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Profil & amis.
  // ---------------------------------------------------------------------------

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

  Future<void> updatePseudo(String pseudo) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await _client.from('profiles').update({'pseudo': pseudo}).eq('id', uid);
    } catch (e) {
      debugPrint('Mise à jour du pseudo impossible : $e');
    }
  }

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
      if (e.code == '23505') return 'Demande déjà envoyée.';
      debugPrint('Demande d\'ami impossible : $e');
      return 'Impossible d\'envoyer la demande.';
    } catch (e) {
      debugPrint('Demande d\'ami impossible : $e');
      return 'Impossible d\'envoyer la demande.';
    }
  }

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
    final unique = ids.toSet().toList();
    final rows = await _client
        .from('profiles')
        .select('id, pseudo')
        .inFilter('id', unique);
    return {
      for (final r in List<Map<String, dynamic>>.from(rows))
        r['id'] as String: (r['pseudo'] as String?) ?? 'Péteur anonyme',
    };
  }

  // ---------------------------------------------------------------------------
  // Conversations (fils privés / groupes) & posts.
  // ---------------------------------------------------------------------------

  Future<List<ConversationSummary>> fetchConversations() async {
    if (userId == null) return [];
    try {
      final rows = await _client.rpc('my_conversations');
      return [
        for (final r in List<Map<String, dynamic>>.from(rows))
          ConversationSummary.fromRow(r),
      ];
    } catch (e) {
      debugPrint('Chargement des conversations impossible : $e');
      return [];
    }
  }

  Future<int> countUnreadTotal() async {
    final convs = await fetchConversations();
    return convs.fold<int>(0, (a, c) => a + c.unread);
  }

  /// Ouvre (ou crée) le fil direct avec un ami. Renvoie l'id de conversation.
  Future<String?> openDirect(String friendId) async {
    try {
      final res =
          await _client.rpc('get_or_create_direct', params: {'other': friendId});
      return res as String?;
    } catch (e) {
      debugPrint('Ouverture du fil direct impossible : $e');
      return null;
    }
  }

  /// Crée un groupe et y ajoute les amis choisis. Renvoie l'id, ou null.
  Future<String?> createGroup(String name, List<String> friendIds) async {
    final uid = userId;
    if (uid == null) return null;
    try {
      final conv = await _client
          .from('conversations')
          .insert({'kind': 'group', 'name': name, 'created_by': uid})
          .select('id')
          .single();
      final convId = conv['id'] as String;
      // Je me joins d'abord (requis par la policy avant d'ajouter des amis).
      await _client
          .from('conversation_members')
          .insert({'conversation_id': convId, 'user_id': uid});
      if (friendIds.isNotEmpty) {
        await _client.from('conversation_members').insert([
          for (final fid in friendIds)
            {'conversation_id': convId, 'user_id': fid},
        ]);
      }
      return convId;
    } catch (e) {
      debugPrint('Création de groupe impossible : $e');
      return null;
    }
  }

  Future<List<Post>> fetchPosts(String conversationId) async {
    final uid = userId;
    try {
      final rows = await _client
          .from('posts')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return [];

      final pseudos =
          await _pseudosFor([for (final r in list) r['sender_id'] as String]);
      final postIds = [for (final r in list) r['id'] as String];
      final reactionRows = await _client
          .from('post_reactions')
          .select('post_id, user_id, emoji')
          .inFilter('post_id', postIds);

      final counts = <String, Map<String, int>>{};
      final mine = <String, Set<String>>{};
      for (final r in List<Map<String, dynamic>>.from(reactionRows)) {
        final pid = r['post_id'] as String;
        final emoji = r['emoji'] as String;
        (counts[pid] ??= {})[emoji] = ((counts[pid]![emoji]) ?? 0) + 1;
        if (r['user_id'] == uid) (mine[pid] ??= {}).add(emoji);
      }

      return [
        for (final r in list)
          Post(
            id: r['id'] as String,
            senderId: r['sender_id'] as String,
            senderPseudo: pseudos[r['sender_id']] ?? 'Péteur anonyme',
            name: r['name'] as String,
            durationMs: (r['duration_ms'] as num).toInt(),
            audioUrl: publicUrlFor(r['audio_path'] as String),
            latitude: (r['latitude'] as num?)?.toDouble(),
            longitude: (r['longitude'] as num?)?.toDouble(),
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            reactions: counts[r['id']] ?? {},
            myReactions: mine[r['id']] ?? {},
          ),
      ];
    } catch (e) {
      debugPrint('Chargement des posts impossible : $e');
      return [];
    }
  }

  /// Partage un pet dans une conversation. Renvoie true si posté.
  Future<bool> postFart(String conversationId, FartRecording rec) async {
    final uid = userId;
    if (uid == null) return false;
    final url = rec.audioUrl;
    final path = url == null ? null : storagePathFromUrl(url);
    if (path == null) return false; // pas encore synchronisé
    try {
      await _client.from('posts').insert({
        'conversation_id': conversationId,
        'sender_id': uid,
        'fart_id': rec.id,
        'name': rec.name,
        'duration_ms': rec.durationMs,
        'audio_path': path,
        'latitude': rec.latitude,
        'longitude': rec.longitude,
      });
      return true;
    } catch (e) {
      debugPrint('Partage du pet impossible : $e');
      return false;
    }
  }

  Future<void> reactToPost(String postId, String emoji,
      {required bool currentlyOn}) async {
    final uid = userId;
    if (uid == null) return;
    try {
      if (currentlyOn) {
        await _client
            .from('post_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid)
            .eq('emoji', emoji);
      } else {
        await _client.from('post_reactions').insert({
          'post_id': postId,
          'user_id': uid,
          'emoji': emoji,
        });
      }
    } catch (e) {
      debugPrint('Réaction impossible : $e');
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await _client
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('Marquage lu impossible : $e');
    }
  }

  /// Tous les posts géolocalisés de mes conversations (pour la carte).
  Future<List<Post>> fetchCommunityLocated() async {
    try {
      final convs = await fetchConversations();
      final result = <Post>[];
      for (final c in convs) {
        final posts = await fetchPosts(c.id);
        result.addAll(posts.where((p) => p.hasLocation));
      }
      return result;
    } catch (e) {
      debugPrint('Chargement carte communauté impossible : $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Lecture des octets audio (natif : fichier ; web : blob URL).
  // ---------------------------------------------------------------------------
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
