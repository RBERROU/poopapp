import 'package:flutter/material.dart';
import 'screens/collection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'services/storage_service.dart';
import 'state/recordings_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = RecordingsRepository(StorageService());
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
      theme: AppTheme.dark,
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

  @override
  Widget build(BuildContext context) {
    const titles = ['Just Fart', 'Ma collection', 'Carte'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(repository: widget.repository),
          CollectionScreen(repository: widget.repository),
          MapScreen(repository: widget.repository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_rounded),
            label: 'Enregistrer',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_rounded),
            label: 'Collection',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_rounded),
            label: 'Carte',
          ),
        ],
      ),
    );
  }
}
