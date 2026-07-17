import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/fart_recording.dart';
import '../services/location_service.dart';
import '../services/recording_service.dart';
import '../state/recordings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/record_button.dart';

/// Onglet "Enregistrer" : gros bouton, minuteur, sauvegarde automatique.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});
  final RecordingsRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RecordingService _rec = RecordingService();
  final LocationService _location = LocationService();
  final Uuid _uuid = const Uuid();

  bool _isRecording = false;
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Future<({double latitude, double longitude})?>? _pendingLocation;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() => _elapsed += const Duration(milliseconds: 100));
      }
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!_isRecording) {
        final ok = await _rec.hasPermission();
        if (!ok) {
          _snack('Autorise le micro pour enregistrer.');
          return;
        }
        await _rec.start();
        _pendingLocation = _location.getCurrentPosition();
        setState(() {
          _isRecording = true;
          _elapsed = Duration.zero;
        });
        _startTimer();
      } else {
        _timer?.cancel();
        final result = await _rec.stop();
        setState(() => _isRecording = false);
        if (result != null && result.durationMs > 300) {
          await _saveRecording(result.path, result.durationMs);
        } else {
          _snack('Trop court ! Maintiens un peu plus longtemps.');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveRecording(String path, int durationMs) async {
    final location = await _pendingLocation;
    _pendingLocation = null;
    final number = widget.repository.items.length + 1;
    final rec = FartRecording(
      id: _uuid.v4(),
      name: 'Pet #$number',
      filePath: path,
      createdAt: DateTime.now(),
      durationMs: durationMs,
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
    await widget.repository.add(rec);
    _snack('Enregistré ! Direction ta collection.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.bubble, AppTheme.bubbleDeep],
        ),
      ),
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedDisplayText(
            _isRecording ? 'Ça pète ! 💥' : 'Prêt à péter ?',
            fontSize: 30,
            color: Colors.white,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 26,
            child: Text(
              _isRecording ? '$seconds s' : "Appuie et lâche l'ambiance",
              style: TextStyle(
                fontSize: _isRecording ? 18 : 14,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 36),
          RecordButton(isRecording: _isRecording, onTap: _toggle),
          const SizedBox(height: 40),
          Transform.rotate(
            angle: 0.035,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: AppTheme.stickerCard(
                color: AppTheme.mint,
                radius: 999,
                dx: 3,
                dy: 3,
              ),
              child: Text(
                _isRecording ? 'Appuie pour arrêter' : 'Maintiens pour enregistrer',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppTheme.ink,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
