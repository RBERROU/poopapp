import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connexion anonyme Supabase : zéro friction, l'utilisateur a un compte
/// sans le savoir. La session est persistée localement par supabase_flutter,
/// donc l'identité reste stable entre les lancements sur un même appareil.
class AuthService {
  static const _timeout = Duration(seconds: 8);

  /// Garantit une session (anonyme si besoin) et un profil avec pseudo.
  /// Ne lance jamais d'exception : hors ligne, l'app reste en mode local.
  Future<void> ensureSignedIn() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously().timeout(_timeout);
      }
      final user = client.auth.currentUser;
      if (user == null) return;

      // Pseudo par défaut dérivé de l'id ; l'utilisateur pourra le changer.
      // ignoreDuplicates : ne réécrase pas un pseudo déjà choisi.
      final pseudo =
          'Péteur ${user.id.substring(0, 4).toUpperCase()}';
      await client.from('profiles').upsert(
        {'id': user.id, 'pseudo': pseudo},
        ignoreDuplicates: true,
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('Auth Supabase indisponible (mode local) : $e');
    }
  }
}
