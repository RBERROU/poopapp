import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/collection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_service.dart';
import 'services/storage_service.dart';
import 'state/recordings_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Backend optionnel : si Supabase est injoignable, l'app reste 100 % locale.
  CloudService? cloud;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    await AuthService().ensureSignedIn();
    cloud = CloudService(Supabase.instance.client);
  } catch (e) {
    debugPrint('Supabase indisponible, mode local : $e');
  }

  final repository = RecordingsRepository(StorageService(), cloud);
  await repository.load();
  runApp(JustFartApp(repository: repository));
}

class JustFartApp extends StatelessWidget {
  const JustFartApp({super.key, required this.repository});
  final RecordingsRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Just Fart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: RootScaffold(repository: repository),
    );
  }
}

/// Coquille principale avec la navigation par onglets.
/// IndexedStack garde les deux écrans vivants (un enregistrement en cours
/// n'est pas perdu si on change d'onglet).
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key, required this.repository});
  final RecordingsRepository repository;

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  static const _titles = ['Just Fart', 'Ma collection', 'Carte'];
  static const _tabs = [
    (emoji: '🎙️', label: 'Enregistrer'),
    (emoji: '💿', label: 'Collection'),
    (emoji: '🗺️', label: 'Carte'),
  ];

  @override
  Widget build(BuildContext context) {
    // Onglet 0 (Enregistrer) : fond rose plein, texte blanc.
    final onBubble = _index == 0;
    return Scaffold(
      backgroundColor: onBubble ? AppTheme.bubble : AppTheme.cream,
      appBar: AppBar(
        title: Text(
          _titles[_index],
          style: TextStyle(color: onBubble ? Colors.white : AppTheme.ink),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(repository: widget.repository),
          CollectionScreen(repository: widget.repository),
          MapScreen(repository: widget.repository),
        ],
      ),
      bottomNavigationBar: _PopNavBar(
        index: _index,
        tabs: _tabs,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Barre de navigation "pop" : emojis chunky, onglet actif dans une pastille
/// jaune contourée avec ombre dure.
class _PopNavBar extends StatelessWidget {
  const _PopNavBar({
    required this.index,
    required this.tabs,
    required this.onSelected,
  });

  final int index;
  final List<({String emoji, String label})> tabs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.paper,
        border: Border(top: BorderSide(color: AppTheme.ink, width: 4)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _NavItem(
                  emoji: tabs[i].emoji,
                  label: tabs[i].label,
                  active: i == index,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.emoji,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 16 : 12,
          vertical: 8,
        ),
        decoration: active
            ? AppTheme.stickerCard(color: AppTheme.zap, radius: 16, dx: 3, dy: 3)
            : const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: 24,
                color: active ? null : AppTheme.ink.withValues(alpha: 0.45),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
