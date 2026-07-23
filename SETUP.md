# Just Fart — Guide d'installation & d'onboarding (Windows)

Ce document permet à un nouveau développeur (et à son assistant IA type Claude Code)
de reproduire l'environnement de travail et de comprendre le projet **de A à Z**.
Il est écrit pour **Windows** (le reste de l'équipe est sous Windows).

---

## 1. C'est quoi Just Fart ?

Application mobile **Flutter** (Dart) : enregistrer, collectionner et **partager ses
pets** entre amis, de façon **privée et communautaire** (pas de contenu public).

- **Cross-plateforme** : web/PWA, iOS, Android — même code source (`lib/`).
- **Modèle produit** : tu ajoutes des amis (par code), vous discutez dans des
  **conversations** (fils privés à deux, ou groupes) où vous vous envoyez des pets,
  comme une messagerie. Une **carte** montre les pets géolocalisés de ta communauté
  (position floutée au quartier).
- **Backend** : **Supabase** (base Postgres + stockage audio + auth anonyme).
- **100 % gratuit** au démarrage (paliers gratuits de tous les services).

### Stack technique

| Couche | Techno |
|---|---|
| App | Flutter / Dart |
| Backend | Supabase (Postgres, Storage, Auth) |
| Carte | MapLibre (tuiles vectorielles OpenFreeMap, sans clé API) |
| Déploiement web | Netlify (auto sur push) |
| Déploiement iOS | Codemagic → TestFlight |

Packages Flutter clés : `record` (capture audio), `audioplayers`, `supabase_flutter`,
`maplibre`, `geolocator`, `share_plus`, `shared_preferences`, `path_provider`, `uuid`, `intl`.

---

## 2. Ce qu'il faut installer (Windows)

### 2.1 Indispensable pour développer

1. **Flutter SDK** (canal *stable*, testé avec 3.44.6)
   - Suivre le guide officiel : https://docs.flutter.dev/get-started/install/windows
   - En résumé : télécharger le SDK, l'extraire (ex. `C:\src\flutter`), puis ajouter
     `C:\src\flutter\bin` au **PATH** (variables d'environnement Windows).
   - Dart est **inclus** dans Flutter (pas d'install séparée).

2. **Git** — https://git-scm.com/download/win
   - Installe aussi **Git Bash**, utile pour les scripts.

3. **Mode développeur Windows** — ⚠️ **OBLIGATOIRE**
   - Flutter en a besoin pour compiler (liens symboliques des plugins).
   - Ouvre : `Win + R` → tape `ms-settings:developers` → active **« Mode développeur »**.
   - Sans ça, `flutter run` / `flutter build` échoue avec « Building with plugins requires symlink support ».

4. **Google Chrome** — la boucle de dev principale se fait sur le web (`flutter run -d chrome`).

5. **Un éditeur** : **VS Code** (recommandé) + l'extension **Flutter** (elle installe
   l'extension Dart automatiquement). Android Studio fonctionne aussi.

### 2.2 Optionnel (selon les besoins)

- **Android Studio + SDK Android** : uniquement pour tester sur **émulateur/téléphone
  Android**. Pas nécessaire si on teste via web + iPhone (TestFlight).
- **Python 3 + Pillow** (`pip install pillow`) : uniquement pour **régénérer l'icône**
  de l'app (`tool/make_icon.py`). Occasionnel.

### 2.3 Vérifier l'installation

```bash
flutter doctor
```
Les lignes **Flutter**, **Chrome (web)** et **VS Code** doivent être vertes.
La partie **Android** peut rester rouge si on ne cible pas Android — ce n'est pas bloquant.
**Pas besoin de Node.js** : les builds web (Netlify) et iOS (Codemagic) tournent dans le cloud.

---

## 3. Cloner et lancer l'app

```bash
# 1. Cloner le repo (URL à adapter si on passe sur un GitHub d'organisation)
git clone https://github.com/RBERROU/poopapp.git
cd poopapp

# 2. Installer les dépendances
flutter pub get

# 3. Lancer en mode web (hot reload : appuyer sur "r" pour recharger)
flutter run -d chrome
```

> ⚠️ Vérifie que le **Mode développeur Windows** est activé avant de lancer (étape 2.3).

**Le backend fonctionne immédiatement** : les identifiants Supabase (URL + clé publique)
sont déjà dans le code (`lib/config/supabase_config.dart`). Un nouveau développeur qui
clone le repo se connecte au **même** projet Supabase — il n'a **rien à recréer** côté base.

---

## 4. Accès aux services cloud (pour gérer déploiement & backend)

Pour **juste coder et lancer l'app**, les sections 2 et 3 suffisent. Pour **gérer les
déploiements ou la base**, il faut être invité sur ces comptes :

| Service | Rôle | Accès |
|---|---|---|
| **GitHub** | Le code | Être membre du repo / de l'organisation |
| **Supabase** | Base de données, stockage audio, auth | Dashboard : https://supabase.com (projet `fjuquhbljkfxzvwdkkrh`) |
| **Netlify** | Déploiement web auto (PWA) | Dashboard Netlify (site `thepoopapp`) |
| **Codemagic** | Builds iOS → TestFlight | Dashboard Codemagic |
| **Apple Developer** | Signature iOS, TestFlight | App Store Connect (bundle `com.justfart.app`) |

---

## 5. Les pipelines de déploiement

- **Web / PWA (automatique).** À **chaque `git push` sur `main`**, Netlify reconstruit
  et déploie sur **thepoopapp.netlify.app** (~1–2 min). Config : `netlify.toml`
  (Netlify clone le SDK Flutter puis lance `flutter build web --release`).

- **iOS (manuel).** Un build se déclenche **à la main** dans l'interface Codemagic
  (workflow `ios-testflight`, config `codemagic.yaml`). Il build sur un Mac cloud,
  signe l'app et l'envoie sur **TestFlight** (~15–20 min). La signature est déjà
  configurée (certificat + profil stockés dans Codemagic, clé API App Store Connect).
  ⚠️ **Ne pas casser la config de signature.** Minutes macOS limitées → builds aux jalons.

---

## 6. La base de données Supabase

Le schéma **actuel** est dans **`supabase/schema_v2.sql`** (modèle « conversations »).
Les autres fichiers (`schema.sql`, `schema_social.sql`, `schema_friends.sql`) sont
**historiques** (versions précédentes, déjà remplacées) — ne pas les rejouer.

- La base du projet partagé est **déjà à jour** : un nouveau dev n'a **rien à exécuter**.
- Pour repartir d'une base vierge (ou sur un nouveau projet Supabase) : exécuter
  **tout `schema_v2.sql`** dans le **SQL Editor** du dashboard. ⚠️ Ce script est
  **destructif** (il supprime les tables existantes).

Tables principales : `profiles`, `friendships`, `farts` (collection perso, privée),
`conversations`, `conversation_members`, `posts` (pets partagés), `post_reactions`.
La sécurité repose sur la **RLS** (Row Level Security) : on ne voit que ses propres
conversations. Vérifié : un étranger ne peut lire aucun contenu privé.

---

## 7. Boucle de dev & commandes utiles

```bash
flutter run -d chrome          # lancer sur le web (hot reload avec "r")
flutter analyze                # analyse statique (doit être clean avant de push)
flutter test                   # tests
flutter build web --release    # build web de prod (ce que fait Netlify)
flutter pub get                # (ré)installer les dépendances
flutter clean                  # nettoyer le cache de build si comportement bizarre
```

Workflow type : coder → `flutter run -d chrome` pour voir en direct → `flutter analyze`
→ `git commit` + `git push` → Netlify redéploie la PWA automatiquement.

---

## 8. Pièges connus (à savoir absolument)

- **Mode développeur Windows** requis (voir 2.3), sinon le build échoue.
- **Comptes anonymes liés à l'appareil/navigateur.** Chaque instance de l'app (PWA sur
  un navigateur donné, ou TestFlight) crée un **compte anonyme distinct** avec son
  propre **code ami**. Pour s'ajouter entre potes, il faut être sur **la même version**.
  (Le fix durable prévu : « Se connecter avec Apple/Google ».)
- **Micro sur iOS Safari (PWA)** : capricieux. L'enregistrement fiable sur iPhone passe
  par **TestFlight** (app native). Sur Android et desktop, le micro web fonctionne.
- **iOS non testable en local** (pas de Mac dans l'équipe) : tout changement touchant
  iOS se vérifie via un **build Codemagic**. Le web (Netlify) est la boucle de test rapide.
- **Carte MapLibre** : nécessite les scripts `maplibre-gl` dans `web/index.html` (déjà
  présents) pour le web.

---

## 9. Structure du code (`lib/`)

```
lib/
├── main.dart                 # point d'entrée, navigation (4 onglets), init Supabase
├── config/                   # supabase_config.dart (URL + clé publique)
├── models/                   # structures de données (FartRecording, social...)
├── services/                 # audio (record/player), stockage local, cloud (Supabase), auth
├── state/                    # recordings_repository.dart (source de vérité, ChangeNotifier)
├── screens/                  # écrans : enregistrer, conversations, fil, collection, carte, amis, onboarding
├── widgets/                  # composants réutilisables (bouton record, cartes, sélecteurs)
└── theme/                    # app_theme.dart (identité visuelle "candy pop")
```

Autres dossiers utiles : `supabase/` (schémas SQL), `tool/` (génération d'icône),
`android/` `ios/` `web/` (config par plateforme, générées par Flutter).

---

## 10. Contexte pour l'assistant IA (Claude Code)

Si tu es un assistant IA qui aide sur ce projet, voici l'essentiel :

- **Architecture** : l'app est **local-first** (la collection perso marche hors ligne via
  `shared_preferences` + fichiers locaux) avec une **couche de synchronisation Supabase**
  par-dessus. `RecordingsRepository` (ChangeNotifier) est la source de vérité en mémoire ;
  `CloudService` encapsule tous les appels Supabase et **échoue en silence** (l'app ne
  doit jamais planter si le réseau tombe).
- **Modèle social** : amis (demande/acceptation par `friend_code`) → **conversations**
  (`direct` ou `group`) → **posts** (pets partagés) → **réactions**. Sécurité via **RLS**
  Postgres + fonctions `SECURITY DEFINER` (`is_member`, `are_friends`, `get_or_create_direct`,
  `my_conversations`) pour éviter la récursion RLS.
- **Vérification** : après un changement, lancer `flutter analyze` puis
  `flutter build web --release`. Le backend se teste en réel contre l'API REST Supabase
  (auth anonyme + requêtes) — la clé publique est dans `lib/config/supabase_config.dart`.
- **Déploiement** : `git push` sur `main` → Netlify redéploie le web. iOS = build manuel
  Codemagic (ne pas toucher à la signature).
- **Contraintes** : Windows (Mode dev requis), pas de Mac (iOS en aveugle via Codemagic),
  comptes anonymes par appareil, micro limité en PWA iOS Safari.
- **Style de code** : commentaires en français, identité visuelle « candy pop » centralisée
  dans `lib/theme/app_theme.dart` (couleurs, contours « sticker », ombres dures).
