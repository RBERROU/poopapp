// Smoke test : l'app démarre et affiche l'onboarding au premier lancement.

import 'package:flutter_test/flutter_test.dart';

import 'package:justfart/main.dart';
import 'package:justfart/services/storage_service.dart';
import 'package:justfart/state/recordings_repository.dart';

void main() {
  testWidgets('Onboarding s\'affiche au premier lancement', (tester) async {
    final storage = StorageService();
    await tester.pumpWidget(JustFartApp(
      repository: RecordingsRepository(storage),
      storage: storage,
      onboarded: false,
    ));
    await tester.pump();

    expect(find.text('C\'est parti ! 🎉'), findsOneWidget);
  });

  testWidgets('L\'app principale s\'affiche une fois onboardé', (tester) async {
    final storage = StorageService();
    await tester.pumpWidget(JustFartApp(
      repository: RecordingsRepository(storage),
      storage: storage,
      onboarded: true,
    ));
    await tester.pump();

    // Le prompt de l'écran d'enregistrement est en 2 couches (contour + fond).
    expect(find.text('Prêt à péter ?'), findsWidgets);
    expect(find.text('C\'est parti ! 🎉'), findsNothing);
  });
}
