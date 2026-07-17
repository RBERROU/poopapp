import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/fart_recording.dart';
import '../services/player_service.dart';
import '../state/recordings_repository.dart';
import '../theme/app_theme.dart';

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
      backgroundColor: AppTheme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppTheme.ink, width: AppTheme.stroke),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('dd/MM/yy · HH:mm').format(r.createdAt)} · ${r.durationLabel}',
              style: TextStyle(
                color: AppTheme.ink.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _player.play(r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: AppTheme.stickerCard(
                  color: AppTheme.bubble,
                  radius: 999,
                  dx: 3,
                  dy: 3,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Écouter',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun pet géolocalisé',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Autorise la localisation lors\ndu prochain enregistrement !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
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
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () => _showDetails(r),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.bubble,
                            border:
                                Border.all(color: AppTheme.ink, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: AppTheme.ink,
                                offset: Offset(2, 2),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('💨', style: TextStyle(fontSize: 20)),
                          ),
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
