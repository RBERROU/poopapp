import 'package:shared_preferences/shared_preferences.dart';
import '../models/fart_recording.dart';

/// Persiste la liste des enregistrements (uniquement les métadonnées).
/// Les fichiers audio restent dans le dossier documents de l'app.
class StorageService {
  static const String _key = 'justfart_recordings_v1';
  static const String _onboardedKey = 'justfart_onboarded_v1';

  /// true si l'utilisateur a déjà passé l'écran d'accueil.
  Future<bool> hasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

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
