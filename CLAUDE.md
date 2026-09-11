# ChevreuilScan — Consignes pour Claude

## Projet
Application Flutter iOS/Android — habitats du chevreuil selon la saison (pré-rut, rut, post-rut).
Réutilise le schéma d'attributs écoforestiers du MFFP déjà utilisé par EcoMap/OrignalScan
(`type_couv`, `gr_ess`, `cl_age`, `cl_drai`, `cl_dens`, `cl_haut`, `cl_pent`, `origine`, `type_eco`, `code_couv`).
Prix unique : 9,99 $ (pas d'abonnement).

Dépôt : `bastienbouchard/ChevreuilScan`. Bundle ID : `com.bastienbouchard.chevreuilscan`.

## Build & déploiement
- **Branche de travail : `main`** — build toujours depuis main dans Codemagic.
- Toujours merger les branches de travail sur `main` avant de terminer.
- Incrémenter le build number (`pubspec.yaml` → `version: x.y.z+N`) à chaque série de modifications avant de pousser.
- Workflow Codemagic défini dans `codemagic.yaml` (versionné, pas configuré via l'UI) :
  - `android-release` : groupe d'env `CS_Android` (garder un keystore distinct de celui d'OrignalScan).
  - `ios-release` : groupe d'env `BB` (réutilise la clé API App Store Connect d'EcoMap — clé de compte, pas d'app).

## État actuel (2026-09-11)
- Scoring forêt + champs : fait, testé, calibré contre le guide officiel du Forestier en chef (FIC-00869-Cerf-de-Virginie).
- Carte interactive flutter_map : faite (sélecteur de saison, panneau d'explication au tap).
- Données écoforestières : tuiles province entière chargées à la volée depuis le bucket R2 public d'EcoMap (`https://pub-5c51ef289e6943dbb647c2a2d1baa3bf.r2.dev`) — pas de pipeline à régénérer.
- Ravages légaux MFFP : couche distincte affichée en tout temps (259 polygones province entière, bundlés).
- Module champs : dessin de polygone + formulaire + persistance locale (`shared_preferences`) — fait.
- `codemagic.yaml` créé — reste à faire côté utilisateur (hors de portée de Claude) : créer l'app dans App Store Connect, enregistrer le bundle ID, créer un keystore Android, connecter le repo GitHub à Codemagic et créer le groupe d'env `CS_Android`.

## Prochaines étapes
- Cache hors-ligne des tuiles écoforestières (comme EcoMap) pour usage en forêt sans réseau.
- Suivre les étapes manuelles ci-dessus pour débloquer le premier build Codemagic.

## Stack technique
- Flutter / Dart, flutter_map + latlong2, shared_preferences, http

## Conventions
- Langue de l'interface : français canadien
- Pas de commentaires évidents dans le code
- Pas de fichiers README ou docs sauf si demandé
- Commits en anglais, messages courts et descriptifs
