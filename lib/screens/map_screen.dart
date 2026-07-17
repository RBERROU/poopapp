import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/fart_recording.dart';
import '../services/player_service.dart';
import '../state/recordings_repository.dart';

/// Onglet "Carte" : affiche tous les pets géolocalisés sur une carte OpenStreetMap.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.repository});
  final RecordingsRepository repository;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PlayerService _player = PlayerService();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _showDetails(FartRecording r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('dd/MM/yy · HH:mm').format(r.createdAt)} · ${r.durationLabel}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _player.play(r.filePath),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Écouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final located =
            widget.repository.items.where((r) => r.hasLocation).toList();
        if (located.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                "Aucun pet géolocalisé pour l'instant.\n"
                'Autorise la localisation lors du prochain enregistrement !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ),
          );
        }

        final points =
            located.map((r) => LatLng(r.latitude!, r.longitude!)).toList();

        return FlutterMap(
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 14,
            initialCameraFit: points.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(points),
                    padding: const EdgeInsets.all(48),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.justfart.app',
            ),
            MarkerLayer(
              markers: located
                  .map(
                    (r) => Marker(
                      point: LatLng(r.latitude!, r.longitude!),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showDetails(r),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}
