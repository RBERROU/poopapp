import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

/// Onglet "Carte" : les pets géolocalisés de ta communauté (tes conversations),
/// position floutée au quartier. Rendu vectoriel MapLibre, style pastel + 3D
/// (dans l'esprit Snapchat), sans clé API.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.cloud});
  final CloudService? cloud;

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  // Style vectoriel gratuit et coloré (OpenFreeMap, aucune clé).
  static const _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  final PlayerService _player = PlayerService();
  List<Post> _located = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Arrondit au quartier (~1 km) : jamais la position exacte.
  Geographic _fuzz(double lat, double lng) => Geographic(
        lon: (lng * 100).round() / 100,
        lat: (lat * 100).round() / 100,
      );

  Future<void> load() async {
    final cloud = widget.cloud;
    if (cloud == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final posts = await cloud.fetchCommunityLocated();
    if (!mounted) return;
    setState(() {
      _located = posts;
      _loading = false;
    });
  }

  void _showDetails(Post p) {
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
            Text(p.name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink)),
            const SizedBox(height: 4),
            Text('de ${p.senderPseudo} · ${p.durationLabel}',
                style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _player.playUrl(p.audioUrl),
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
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.bubble));
    }
    if (_located.isEmpty) return _empty();

    // Point flouté par pet + centre = moyenne (approx.) pour cadrer.
    final pins = [
      for (final p in _located) (post: p, pt: _fuzz(p.latitude!, p.longitude!)),
    ];
    final avgLon =
        pins.map((e) => e.pt.lon).reduce((a, b) => a + b) / pins.length;
    final avgLat =
        pins.map((e) => e.pt.lat).reduce((a, b) => a + b) / pins.length;

    return MapLibreMap(
      options: MapOptions(
        initStyle: _styleUrl,
        initCenter: Geographic(lon: avgLon, lat: avgLat),
        initZoom: 12,
        initPitch: 45, // inclinaison "3D" façon Snap Map
        maxPitch: 60,
      ),
      children: [
        WidgetLayer(
          allowInteraction: true,
          markers: [
            for (final pin in pins)
              Marker(
                point: pin.pt,
                size: const Size(58, 66),
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () => _showDetails(pin.post),
                  child: _PopPin(pseudo: pin.post.senderPseudo),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('Carte vide',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink)),
              const SizedBox(height: 8),
              Text(
                'Les pets géolocalisés de tes potes\napparaîtront ici (position au quartier).',
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

/// Pin funky : bulle colorée avec initiale + petit pseudo dessous.
class _PopPin extends StatelessWidget {
  const _PopPin({required this.pseudo});
  final String pseudo;

  @override
  Widget build(BuildContext context) {
    final initial =
        pseudo.isNotEmpty ? pseudo.characters.first.toUpperCase() : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.bubble,
            border: Border.all(color: AppTheme.ink, width: 3),
            boxShadow: const [
              BoxShadow(color: AppTheme.ink, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
          child: Text(initial,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.white)),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.zap,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.ink, width: 1.5),
          ),
          child: Text(
            pseudo.length > 8 ? '${pseudo.substring(0, 7)}…' : pseudo,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 9,
                color: AppTheme.ink),
          ),
        ),
      ],
    );
  }
}
