import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/fart_recording.dart';
import '../services/cloud_service.dart';
import '../services/storage_service.dart';

/// Source de vérité en mémoire pour la collection de pets.
/// Étend ChangeNotifier : l'UI se reconstruit via ListenableBuilder,
/// sans aucune librairie de state management externe.
///
/// Le stockage local reste la référence immédiate (l'app marche hors ligne) ;
/// le cloud Supabase est une couche de synchronisation en arrière-plan.
class RecordingsRepository extends ChangeNotifier {
  RecordingsRepository(this._storage, [this._cloud]);
  final StorageService _storage;
  final CloudService? _cloud;

  final List<FartRecording> _items = [];
  List<FartRecording> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _storage.load());
    _sort();
    notifyListeners();
    // Synchronisation cloud en arrière-plan : ne bloque pas le démarrage.
    unawaited(_syncWithCloud());
  }

  Future<void> add(FartRecording rec) async {
    _items.insert(0, rec);
    await _storage.save(_items);
    notifyListeners();
    unawaited(_uploadAndMark(rec));
  }

  Future<void> rename(String id, String name) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(name: name);
    await _storage.save(_items);
    notifyListeners();
    final cloud = _cloud;
    if (cloud != null) unawaited(cloud.renameFart(id, name));
  }

  Future<void> delete(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final rec = _items.removeAt(i);
    // supprime aussi le fichier audio du disque (jamais de File sur le web)
    if (!kIsWeb && rec.filePath.isNotEmpty) {
      final file = File(rec.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _storage.save(_items);
    notifyListeners();
    final cloud = _cloud;
    if (cloud != null) unawaited(cloud.deleteFart(rec));
  }

  void _sort() =>
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _uploadAndMark(FartRecording rec) async {
    final cloud = _cloud;
    if (cloud == null) return;
    final url = await cloud.uploadFart(rec);
    if (url == null) return;
    final i = _items.indexWhere((e) => e.id == rec.id);
    if (i == -1) return; // supprimé entre-temps
    _items[i] = _items[i].copyWith(audioUrl: url);
    await _storage.save(_items);
    notifyListeners();
  }

  /// Rapatrie les pets connus du serveur et pousse ceux jamais uploadés.
  Future<void> _syncWithCloud() async {
    final cloud = _cloud;
    if (cloud == null || cloud.userId == null) return;
    try {
      final remoteRows = await cloud.fetchMyFarts();
      final localIds = _items.map((e) => e.id).toSet();
      var changed = false;

      for (final row in remoteRows) {
        final id = row['id'] as String;
        final url = cloud.publicUrlFor(row['audio_path'] as String);
        if (!localIds.contains(id)) {
          _items.add(FartRecording.fromCloudRow(row, audioUrl: url));
          changed = true;
        } else {
          final i = _items.indexWhere((e) => e.id == id);
          if (_items[i].audioUrl == null) {
            _items[i] = _items[i].copyWith(audioUrl: url);
            changed = true;
          }
        }
      }

      // Pets locaux jamais synchronisés (enregistrés hors ligne, ou datant
      // d'avant le backend) : on les pousse maintenant.
      for (final rec in List.of(_items)) {
        if (rec.audioUrl != null) continue;
        final url = await cloud.uploadFart(rec);
        if (url != null) {
          final i = _items.indexWhere((e) => e.id == rec.id);
          if (i != -1) {
            _items[i] = _items[i].copyWith(audioUrl: url);
            changed = true;
          }
        }
      }

      if (changed) {
        _sort();
        await _storage.save(_items);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Sync cloud impossible (on réessaiera) : $e');
    }
  }
}
