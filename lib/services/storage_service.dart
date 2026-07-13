import 'package:shared_preferences/shared_preferences.dart';
import '../models/fart_recording.dart';

/// Persiste la liste des enregistrements (uniquement les métadonnées).
/// Les fichiers audio restent dans le dossier documents de l'app.
class StorageService {
  static const String _key = 'poot_recordings_v1';

  Future<List<FartRecording>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return FartRecording.decodeList(raw);
    } catch (_) {
      // données corrompues : on repart propre plutôt que de planter
      return [];
    }
  }

  Future<void> save(List<FartRecording> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, FartRecording.encodeList(list));
  }
}
