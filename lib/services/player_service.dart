import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/fart_recording.dart';

/// Lecture audio via le package `audioplayers`.
/// Source locale quand le fichier existe sur l'appareil, sinon URL cloud
/// (pet synchronisé enregistré ailleurs, ou blob web expiré après rechargement).
class PlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Émis quand la lecture se termine (pour remettre l'UI à zéro).
  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> play(FartRecording rec) async {
    await _player.stop();
    await _player.play(_sourceFor(rec));
  }

  Source _sourceFor(FartRecording rec) {
    if (!kIsWeb &&
        rec.filePath.isNotEmpty &&
        File(rec.filePath).existsSync()) {
      return DeviceFileSource(rec.filePath);
    }
    final url = rec.audioUrl;
    if (url != null) return UrlSource(url);
    // Dernier recours : blob URL web de la session courante.
    return UrlSource(rec.filePath);
  }

  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
