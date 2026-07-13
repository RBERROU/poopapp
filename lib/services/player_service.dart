import 'package:audioplayers/audioplayers.dart';

/// Lecture des fichiers audio locaux via le package `audioplayers`.
class PlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Émis quand la lecture se termine (pour remettre l'UI à zéro).
  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
