import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/feed_item.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';
import '../state/recordings_repository.dart';
import '../theme/app_theme.dart';

/// Onglet "Carte" : le monde des pets géolocalisés.
/// - Tes pets : position précise, pin rose 💨.
/// - Les autres (feed public) : position FLOUTÉE au quartier, pin violet.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.repository, this.cloud});
  final RecordingsRepository repository;
  final CloudService? cloud;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Point unifié affiché sur la carte (mien ou public).
class _Pin {
  final LatLng point;
  final String title;
  final String subtitle;
  final String audioUrl;
  final bool mine;
  const _Pin({
    required this.point,
    required this.title,
    required this.subtitle,
    required this.audioUrl,
    required this.mine,
  });
}

class _MapScreenState extends State<MapScreen> {
  final PlayerService _player = PlayerService();
  List<FeedItem> _feed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    final cloud = widget.cloud;
    if (cloud != null) {
      final feed = await cloud.fetchFeed();
      if (mounted) setState(() => _feed = feed);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_Pin> _collectPins() {
    final pins = <_Pin>[];
    // Mes pets, position précise.
    for (final r in widget.repository.items) {
      if (r.hasLocation) {
        final url = r.audioUrl;
        pins.add(_Pin(
          point: LatLng(r.latitude!, r.longitude!),
          title: r.name,
          subtitle:
              '${DateFormat('dd/MM · HH:mm').format(r.createdAt)} · ${r.durationLabel}',
          audioUrl: url ?? r.filePath,
          mine: true,
        ));
      }
    }
    // Pets des autres, position floutée.
    for (final f in _feed) {
      if (f.hasLocation) {
        pins.add(_Pin(
          point: LatLng(f.latFuzzy!, f.lngFuzzy!),
          title: f.name,
          subtitle: '${f.pseudo} · ${f.durationLabel}',
          audioUrl: f.audioUrl,
          mine: false,
        ));
      }
    }
    return pins;
  }

  void _showDetails(_Pin pin) {
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
            Text(pin.title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink)),
            const SizedBox(height: 4),
            Text(pin.subtitle,
                style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _player.playUrl(pin.audioUrl),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: AppTheme.stickerCard(
                    color: AppTheme.bubble, radius: 999, dx: 3, dy: 3),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Écouter',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
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
        final pins = _collectPins();

        if (_loading && pins.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.bubble),
          );
        }
        if (pins.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text('Carte vide pour l\'instant',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink)),
                  const SizedBox(height: 8),
                  Text(
                    'Enregistre un pet en autorisant\nla localisation pour démarrer !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          );
        }

        final points = pins.map((p) => p.point).toList();
        return FlutterMap(
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 12,
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
              markers: [
                for (final pin in pins)
                  Marker(
                    point: pin.point,
                    width: 46,
                    height: 46,
                    child: GestureDetector(
                      onTap: () => _showDetails(pin),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pin.mine ? AppTheme.bubble : AppTheme.grape,
                          border: Border.all(color: AppTheme.ink, width: 3),
                          boxShadow: const [
                            BoxShadow(
                                color: AppTheme.ink,
                                offset: Offset(2, 2),
                                blurRadius: 0),
                          ],
                        ),
                        child: const Center(
                          child: Text('💨', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
