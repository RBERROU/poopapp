import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/fart_recording.dart';
import '../services/storage_service.dart';

/// Source de vérité en mémoire pour la collection de pets.
/// Étend ChangeNotifier : l'UI se reconstruit via ListenableBuilder,
/// sans aucune librairie de state management externe.
class RecordingsRepository extends ChangeNotifier {
  RecordingsRepository(this._storage);
  final StorageService _storage;

  final List<FartRecording> _items = [];
  List<FartRecording> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _storage.load());
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // récents d'abord
    notifyListeners();
  }

  Future<void> add(FartRecording rec) async {
    _items.insert(0, rec);
    await _storage.save(_items);
    notifyListeners();
  }

  Future<void> rename(String id, String name) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(name: name);
    await _storage.save(_items);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final rec = _items.removeAt(i);
    // supprime aussi le fichier audio du disque
    final file = File(rec.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    await _storage.save(_items);
    notifyListeners();
  }
}
