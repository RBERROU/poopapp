import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Encapsule la capture audio via le package `record`.
/// Mesure aussi la durée de l'enregistrement avec un chronomètre.
class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  Stopwatch? _stopwatch;

  /// Vérifie (et demande si besoin) la permission micro.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> isRecording() => _recorder.isRecording();

  /// Démarre l'enregistrement dans le dossier documents de l'app.
  /// Renvoie le chemin du fichier créé.
  /// Sur le web, il n'y a pas de système de fichiers : `record` ignore le
  /// chemin fourni et renvoie une blob URL directement au `stop()`.
  Future<String> start() async {
    var path = '';
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/pet_${_uuid.v4()}.m4a';
    }
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _stopwatch = Stopwatch()..start();
    return path;
  }

  /// Arrête l'enregistrement. Renvoie le chemin final et la durée en ms.
  Future<({String path, int durationMs})?> stop() async {
    final path = await _recorder.stop();
    final elapsed = _stopwatch?.elapsedMilliseconds ?? 0;
    _stopwatch?.stop();
    _stopwatch = null;
    if (path == null) return null;
    return (path: path, durationMs: elapsed);
  }

  void dispose() => _recorder.dispose();
}
