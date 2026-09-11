# ChevreuilScan — Consignes pour Claude

## Projet
Application Flutter iOS/Android — habitats du chevreuil selon la saison (pré-rut, rut, post-rut).
Réutilise le schéma d'attributs écoforestiers du MFFP déjà utilisé par EcoMap/OrignalScan
(`type_couv`, `gr_ess`, `cl_age`, `cl_drai`, `cl_dens`, `cl_pent`, `origine`, `type_eco`, `code_couv`).
Prix unique : 9,99 $ (pas d'abonnement).

## État actuel
- Scaffold créé, logique de scoring (habitat forestier + champs) implémentée et testée.
- Pas encore de carte interactive, pas de pipeline de tuiles, pas de persistance.

## Prochaines étapes
1. Pipeline de tuiles écoforestières (réutiliser le script depuis `CARTE_ECO_MAJ_PROV.gpkg`, voir EcoMap).
2. Carte interactive (flutter_map) avec sélecteur de saison + couleurs par `ScoreLevel`.
3. Module champs : dessin de polygone sur la carte + formulaire (culture, date de récolte, hauteur, bordures).
4. Panneau d'explication (affiche `HabitatScore.reasons`).

## Build & déploiement
- Incrémenter le build number (`pubspec.yaml` → `version: x.y.z+N`) à chaque série de modifications avant de pousser.

## Stack technique
- Flutter / Dart, flutter_map + latlong2
- Même schéma de données écoforestières que EcoMap/OrignalScan

## Conventions
- Langue de l'interface : français canadien
- Pas de commentaires évidents dans le code
- Pas de fichiers README ou docs sauf si demandé
