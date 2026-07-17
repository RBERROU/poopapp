import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/collection_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
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

  final storage = StorageService();
  final repository = RecordingsRepository(storage, cloud);
  await repository.load();
  final onboarded = await storage.hasOnboarded();
  runApp(JustFartApp(
    repository: repository,
    cloud: cloud,
    storage: storage,
    onboarded: onboarded,
  ));
}

class JustFartApp extends StatefulWidget {
  const JustFartApp({
    super.key,
    required this.repository,
    required this.storage,
    required this.onboarded,
    this.cloud,
  });
  final RecordingsRepository repository;
  final StorageService storage;
  final bool onboarded;
  final CloudService? cloud;

  @override
  State<JustFartApp> createState() => _JustFartAppState();
}

class _JustFartAppState extends State<JustFartApp> {
  late bool _onboarded = widget.onboarded;

  Future<void> _finishOnboarding(String pseudo) async {
    await widget.storage.setOnboarded();
    if (pseudo.isNotEmpty) {
      await widget.cloud?.updatePseudo(pseudo);
    }
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Just Fart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: _onboarded
          ? RootScaffold(repository: widget.repository, cloud: widget.cloud)
          : OnboardingScreen(onDone: _finishOnboarding),
    );
  }
}

/// Coquille principale avec la navigation par onglets.
/// IndexedStack garde les deux écrans vivants (un enregistrement en cours
/// n'est pas perdu si on change d'onglet).
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key, required this.repository, this.cloud});
  final RecordingsRepository repository;
  final CloudService? cloud;

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;
  int _unseen = 0;
  final _inboxKey = GlobalKey<InboxScreenState>();

  static const _inboxIndex = 2;
  static const _titles = [
    'Just Fart',
    'Le monde',
    'Reçus',
    'Ma collection',
    'Carte',
  ];
  static const _tabs = [
    (emoji: '🎙️', label: 'Enregistrer'),
    (emoji: '🌍', label: 'Le monde'),
    (emoji: '📬', label: 'Reçus'),
    (emoji: '💿', label: 'Collection'),
    (emoji: '🗺️', label: 'Carte'),
  ];

  @override
  void initState() {
    super.initState();
    _refreshUnseen();
  }

  Future<void> _refreshUnseen() async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    final n = await cloud.countUnseen();
    if (mounted) setState(() => _unseen = n);
  }

  void _onSelect(int i) {
    setState(() => _index = i);
    if (i == _inboxIndex) {
      _inboxKey.currentState?.load();
    }
    _refreshUnseen();
  }

  Future<void> _openProfile() async {
    final cloud = widget.cloud;
    if (cloud == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FriendsScreen(cloud: cloud)),
    );
    _refreshUnseen();
  }

  @override
  Widget build(BuildContext context) {
    // Onglet 0 (Enregistrer) : fond rose plein, texte blanc.
    final onBubble = _index == 0;
    final fg = onBubble ? Colors.white : AppTheme.ink;
    return Scaffold(
      backgroundColor: onBubble ? AppTheme.bubble : AppTheme.cream,
      appBar: AppBar(
        title: Text(_titles[_index], style: TextStyle(color: fg)),
        actions: [
          if (widget.cloud != null)
            IconButton(
              tooltip: 'Profil & amis',
              onPressed: _openProfile,
              icon: Icon(Icons.account_circle_rounded, color: fg),
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(repository: widget.repository),
          FeedScreen(cloud: widget.cloud),
          InboxScreen(
            key: _inboxKey,
            cloud: widget.cloud,
            onChanged: _refreshUnseen,
          ),
          CollectionScreen(
              repository: widget.repository, cloud: widget.cloud),
          MapScreen(repository: widget.repository, cloud: widget.cloud),
        ],
      ),
      bottomNavigationBar: _PopNavBar(
        index: _index,
        tabs: _tabs,
        badgeIndex: _inboxIndex,
        badgeCount: _unseen,
        onSelected: _onSelect,
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
    this.badgeIndex = -1,
    this.badgeCount = 0,
  });

  final int index;
  final List<({String emoji, String label})> tabs;
  final ValueChanged<int> onSelected;
  final int badgeIndex;
  final int badgeCount;

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _NavItem(
                  emoji: tabs[i].emoji,
                  label: tabs[i].label,
                  active: i == index,
                  badge: i == badgeIndex ? badgeCount : 0,
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
    this.badge = 0,
  });

  final String emoji;
  final String label;
  final bool active;
  final int badge;
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
          horizontal: active ? 14 : 10,
          vertical: 8,
        ),
        decoration: active
            ? AppTheme.stickerCard(color: AppTheme.zap, radius: 16, dx: 3, dy: 3)
            : const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 24,
                    color: active ? null : AppTheme.ink.withValues(alpha: 0.45),
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.bubble,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.ink, width: 2),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
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
