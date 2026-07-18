import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';

/// Création d'un groupe : un nom + une sélection d'amis.
/// Renvoie true (pop) si le groupe a été créé.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.cloud});
  final CloudService cloud;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _selected = <String>{};
  List<Friend> _friends = [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final friends = await widget.cloud.fetchFriends();
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Donne un nom au groupe 😊');
      return;
    }
    if (_selected.isEmpty) {
      _snack('Choisis au moins un pote.');
      return;
    }
    setState(() => _creating = true);
    final id = await widget.cloud.createGroup(name, _selected.toList());
    if (!mounted) return;
    if (id != null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _creating = false);
      _snack('Création impossible, réessaie.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.cream,
        title: const Text('Nouveau groupe'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.bubble))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _name,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppTheme.ink),
                    decoration: InputDecoration(
                      hintText: 'Nom du groupe (ex : Les Pétomanes)',
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.paper,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppTheme.ink, width: 3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppTheme.bubble, width: 3),
                      ),
                    ),
                  ),
                ),
                if (_friends.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'Ajoute des potes d\'abord\npour pouvoir les regrouper !',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final f in _friends) _friendCheck(f),
                      ],
                    ),
                  ),
                _createButton(),
              ],
            ),
    );
  }

  Widget _friendCheck(Friend f) {
    final on = _selected.contains(f.userId);
    return GestureDetector(
      onTap: () => setState(() {
        on ? _selected.remove(f.userId) : _selected.add(f.userId);
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.stickerCard(
            color: on ? AppTheme.zap : AppTheme.paper),
        child: Row(
          children: [
            const Text('🤜', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(f.pseudo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppTheme.ink)),
            ),
            Icon(
              on ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: AppTheme.ink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _createButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _creating ? null : _create,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: AppTheme.stickerCard(
                color: AppTheme.bubble, radius: 999, dx: 3, dy: 3),
            child: _creating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _selected.isEmpty
                        ? 'Créer le groupe'
                        : 'Créer avec ${_selected.length} pote${_selected.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
