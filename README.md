# Just Fart — MVP v0

Application mobile (Flutter) pour **enregistrer, collectionner et partager tes pets**.
Ce dossier contient le code source du premier MVP : 100 % local, aucun serveur, donc 0 € d'infrastructure.

## Ce que fait ce MVP

- Enregistrer un pet (gros bouton micro)
- Sauvegarde automatique dans « Ma collection »
- Lecture, renommage, suppression
- **Partage du fichier audio** via le partage natif du téléphone (WhatsApp, Insta, SMS…)

---

## Prérequis (Windows)

1. **Flutter SDK** — https://docs.flutter.dev/get-started/install/windows
2. **Android Studio** (pour le SDK Android + un émulateur) **ou** un téléphone Android en mode développeur (débogage USB activé).
3. Vérifie l'installation : `flutter doctor` — la partie Android doit être verte.

---

## Installation du projet

Flutter génère lui-même les dossiers de plateforme (`android/`, `ios/`…). Le code fourni est le dossier `lib/` + `pubspec.yaml`. Deux façons de faire :

### Option A — dans ce dossier directement (le plus simple)

1. Ouvre un terminal dans ce dossier.
2. Lance : `flutter create .`
   *(génère `android/`, `ios/`… sans écraser `lib/` ni `pubspec.yaml`)*

### Option B — projet neuf puis copie

1. `flutter create justfart`
2. Remplace `justfart/pubspec.yaml` par celui fourni.
3. Remplace le dossier `justfart/lib/` par le `lib/` fourni.

---

## Permissions micro (obligatoire)

- **Android** — dans `android/app/src/main/AndroidManifest.xml`, ajoute juste avant `<application>` :

  ```xml
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  ```

- **Android** — dans `android/app/build.gradle`, mets `minSdk 23` (requis par le module d'enregistrement).

- **iOS** (plus tard, nécessite un Mac) — dans `ios/Runner/Info.plist`, ajoute la clé `NSMicrophoneUsageDescription` avec un texte du type : « Just Fart a besoin du micro pour enregistrer tes pets. »

---

## Lancer l'app

1. `flutter pub get`
2. Branche ton téléphone (ou lance un émulateur).
3. `flutter run`

---

## Renommer l'app

- **Nom affiché** : `title:` dans `lib/main.dart`, et `name:` / `description:` dans `pubspec.yaml`.
- **Identifiant de package** (`com.tonnom.justfart`) : régénère avec `flutter create --org com.tonnom .`
- **Icône** : à ajouter plus tard via le package `flutter_launcher_icons`.

---

## Dépannage

- Si `flutter pub get` propose des versions majeures plus récentes qui cassent une API, **garde les versions épinglées** du `pubspec.yaml` fourni.
- `flutter doctor -v` pour diagnostiquer l'environnement.

---

## Architecture du code (`lib/`)

- `models/` — structure de données (`FartRecording`)
- `services/` — enregistrement audio, stockage local, lecture
- `state/` — repository (source de vérité, `ChangeNotifier`)
- `widgets/` — bouton d'enregistrement, ligne de collection
- `screens/` — écran d'enregistrement, écran collection
- `theme/` — couleurs et thème

---

## Prochaines étapes (roadmap)

- **v1** — comptes + backend Firebase, feed, effets premium, publicité
- **v2** — géolocalisation + carte des pets
- **v3** — classement hebdomadaire, badges, notifications push

Voir le document *Plan-action-app-pets.md* pour le plan complet (marché, budget, monétisation).
