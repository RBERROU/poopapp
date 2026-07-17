import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pseudo_dialog.dart';

/// Écran "Profil & Amis" : mon pseudo + code ami, ajout par code,
/// demandes reçues, liste d'amis.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.cloud});
  final CloudService cloud;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeController = TextEditingController();
  String _pseudo = '';
  String _myCode = '';
  List<FriendRequest> _requests = [];
  List<Friend> _friends = [];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await widget.cloud.fetchMyProfile();
    final requests = await widget.cloud.fetchIncomingRequests();
    final friends = await widget.cloud.fetchFriends();
    if (!mounted) return;
    setState(() {
      _pseudo = profile?.pseudo ?? '';
      _myCode = profile?.code ?? '';
      _requests = requests;
      _friends = friends;
      _loading = false;
    });
  }

  Future<void> _editPseudo() async {
    final next = await showPseudoDialog(context, current: _pseudo);
    if (next != null && next.isNotEmpty) {
      await widget.cloud.updatePseudo(next);
      await _load();
    }
  }

  Future<void> _addByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _adding = true);
    final found = await widget.cloud.findByCode(code);
    if (found == null) {
      _snack('Aucun pote avec ce code. 🤔');
      setState(() => _adding = false);
      return;
    }
    final msg = await widget.cloud.sendFriendRequest(found.id);
    _codeController.clear();
    if (!mounted) return;
    setState(() => _adding = false);
    _snack(msg);
  }

  Future<void> _respond(FriendRequest req, bool accept) async {
    await widget.cloud.respondToRequest(req.friendshipId, accept: accept);
    await _load();
    _snack(accept ? '${req.pseudo} est ton pote ! 🤝' : 'Demande refusée.');
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
      appBar: AppBar(
        title: const Text('Profil & Amis'),
        backgroundColor: AppTheme.cream,
      ),
      backgroundColor: AppTheme.cream,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.bubble))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.bubble,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _profileCard(),
                  const SizedBox(height: 16),
                  _addCard(),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionTitle('Demandes reçues (${_requests.length})'),
                    for (final r in _requests) _requestTile(r),
                  ],
                  const SizedBox(height: 16),
                  _sectionTitle('Mes potes (${_friends.length})'),
                  if (_friends.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Aucun pote pour l\'instant.\nPartage ton code pour en ajouter !',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink.withValues(alpha: 0.55),
                        ),
                      ),
                    )
                  else
                    for (final f in _friends) _friendTile(f),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4, left: 4),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppTheme.ink)),
      );

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.stickerCard(color: AppTheme.paper),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🙂', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _pseudo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppTheme.ink),
                ),
              ),
              GestureDetector(
                onTap: _editPseudo,
                child: const Icon(Icons.edit_rounded, color: AppTheme.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Ton code ami',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppTheme.ink)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: AppTheme.stickerCard(
                    color: AppTheme.zap, radius: 12, dx: 2, dy: 2),
                child: Text(
                  _myCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 3,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _iconBtn(Icons.copy_rounded, () {
                Clipboard.setData(ClipboardData(text: _myCode));
                _snack('Code copié !');
              }),
              const SizedBox(width: 8),
              _iconBtn(Icons.share_rounded, () {
                Share.share(
                    'Ajoute-moi sur Just Fart 💨 ! Mon code : $_myCode\nthepoopapp.netlify.app');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.stickerCard(color: AppTheme.paper),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajouter un pote',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.ink)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppTheme.ink),
                  decoration: InputDecoration(
                    hintText: 'Code (6 lettres)',
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.ink, width: 2.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.bubble, width: 3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _adding ? null : _addByCode,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: AppTheme.stickerCard(
                      color: AppTheme.bubble, radius: 14, dx: 2, dy: 2),
                  child: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Ajouter',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestTile(FriendRequest r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.stickerCard(color: const Color(0xFFFFF4D6)),
      child: Row(
        children: [
          Expanded(
            child: Text(r.pseudo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppTheme.ink)),
          ),
          _iconBtn(Icons.check_rounded, () => _respond(r, true),
              color: AppTheme.mint),
          const SizedBox(width: 8),
          _iconBtn(Icons.close_rounded, () => _respond(r, false),
              color: Colors.white),
        ],
      ),
    );
  }

  Widget _friendTile(Friend f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.stickerCard(color: const Color(0xFFE4FBF5)),
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
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.white,
          border: Border.all(color: AppTheme.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(color: AppTheme.ink, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Icon(icon, color: AppTheme.ink, size: 22),
      ),
    );
  }
}
