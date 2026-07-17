import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Écran d'accueil affiché une seule fois au tout premier lancement.
/// Souhaite la bienvenue, explique l'app et laisse choisir un pseudo.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onDone,
    this.suggestedPseudo,
  });

  /// Appelé avec le pseudo choisi (peut être vide → on garde l'auto).
  final ValueChanged<String> onDone;
  final String? suggestedPseudo;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _pseudo =
      TextEditingController(text: widget.suggestedPseudo ?? '');

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.grape, AppTheme.bubble],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💨', style: TextStyle(fontSize: 76)),
                  const SizedBox(height: 12),
                  const OutlinedDisplayText(
                    'Just Fart',
                    fontSize: 46,
                    color: AppTheme.zap,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enregistre. Collectionne.\nFais rire tes potes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _card(
                    child: const Column(
                      children: [
                        _FeatureRow(
                          emoji: '🎙️',
                          title: 'Enregistre tes pets',
                          subtitle: 'Un gros bouton, et c\'est parti.',
                        ),
                        SizedBox(height: 16),
                        _FeatureRow(
                          emoji: '🌍',
                          title: 'Découvre le monde',
                          subtitle: 'Le feed des pets des autres.',
                        ),
                        SizedBox(height: 16),
                        _FeatureRow(
                          emoji: '🔥',
                          title: 'Réagis',
                          subtitle: '💨 🔥 😂 🤢 sur chaque pet.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ton pseudo',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pseudo,
                          maxLength: 24,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(24),
                          ],
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ex : Le Baron du Pet',
                            counterText: '',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppTheme.ink, width: 2.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppTheme.bubble, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => widget.onDone(_pseudo.text.trim()),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: AppTheme.stickerCard(
                        color: AppTheme.zap,
                        radius: 999,
                        dx: 4,
                        dy: 4,
                      ),
                      child: const Text(
                        'C\'est parti ! 🎉',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.stickerCard(color: AppTheme.paper),
        child: child,
      );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.ink,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
