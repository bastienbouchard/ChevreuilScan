import '../models/champ.dart';
import '../models/habitat_score.dart';
import '../models/season.dart';

const int _maxFieldScore = 24;

/// Calcule l'intérêt d'un champ pour le chevreuil selon la saison, le type de
/// culture, la date de récolte, la hauteur actuelle et la présence de bordures.
HabitatScore scoreField(Champ champ, Season season, DateTime now) {
  final reasons = <String>[];
  int score = 0;

  final daysSinceHarvest = now.difference(champ.harvestDate).inDays;
  final harvested = daysSinceHarvest >= 0;

  switch (champ.crop) {
    case CropType.trefle:
    case CropType.luzerne:
      score += 6;
      reasons.add('${champ.crop.label} — source de nourriture riche et digestible');
      break;
    case CropType.mais:
    case CropType.cereales:
      if (harvested) {
        score += 7;
        reasons.add('${champ.crop.label} récolté — grain résiduel au sol très attractif');
      } else {
        score += 3;
        reasons.add('${champ.crop.label} sur pied — nourriture peu accessible avant récolte');
      }
      break;
    case CropType.foin:
      score += 3;
      reasons.add('Foin — nourriture modérée, surtout en repousse');
      break;
    case CropType.jachere:
      score += 2;
      reasons.add('Jachère — couvert et broutage occasionnel');
      break;
  }

  if (harvested && daysSinceHarvest <= 30) {
    score += 5;
    reasons.add('Récolté récemment ($daysSinceHarvest j) — résidus de grain encore abondants');
  } else if (harvested && daysSinceHarvest <= 60) {
    score += 2;
    reasons.add('Récolté il y a $daysSinceHarvest j — repousse verte disponible');
  }

  if (champ.hauteurCm < 30) {
    score += season == Season.rut ? 1 : 4;
    reasons.add('Végétation basse — accès facile à la nourriture');
  } else if (champ.hauteurCm >= 100) {
    if (season == Season.rut) {
      score += 4;
      reasons.add('Végétation haute — bon couvert pour les déplacements en rut');
    } else {
      reasons.add('Végétation haute — nourriture peu accessible tant que non récoltée');
    }
  }

  if (champ.hasBordures) {
    score += season == Season.rut ? 5 : 3;
    reasons.add('Bordures/haies — corridor et couvert de bordure');
  }

  return HabitatScore.fromRaw(score.clamp(0, 999), _maxFieldScore, reasons);
}
