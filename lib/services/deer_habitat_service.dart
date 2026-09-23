import '../models/habitat_score.dart';
import '../models/season.dart';

const int _maxPreRut = 33;
const int _maxRut = 22;
const int _maxPostRut = 35;

// Chêne rouge et hêtre à grandes feuilles produisent glands et faînes —
// la nourriture naturelle la plus recherchée du chevreuil à l'automne.
// Code MFFP exact non confirmé pour ce champ (gr_ess à 2 lettres) : on
// vérifie le préfixe ('HE'/'CH') plutôt qu'un code exact pour couvrir les
// variantes plausibles (HE, HEG, CH, CHR, CHB) sans rater de vrais cas.
bool hasPreferredMast(Map props) {
  final ess = (props['gr_ess'] ?? '').toString().toUpperCase();
  return ess.contains('HE') || ess.contains('CH');
}

int _maxForSeason(Season season) => switch (season) {
      Season.preRut => _maxPreRut,
      Season.rut => _maxRut,
      Season.postRut => _maxPostRut,
    };

// Classes d'âge jeunes (régulier ou irrégulier), codes MFFP réels.
bool _isJeune(String age) => age == '10' || age == 'J' || age == 'JIN' || age == 'JIR';

// Peuplement mature/suranné (Forestier en chef : abri hivernal = "mature à suranné").
bool _isMature(String age) {
  final n = int.tryParse(age);
  if (n != null) return n >= 50;
  return age == 'VIR' || age == 'VIN';
}

// cl_drai réel est un code à 1 ou 2 chiffres (ex. '30', '40', '60') — le
// premier chiffre porte la classe de drainage MFFP (0 = excessif, 6 = inondé).
bool _isHumide(String drai) =>
    drai.isNotEmpty && ['4', '5', '6'].contains(drai[0]);

// Norme de stratification écoforestière MFFP (tableau 14) : classes 1 à 4
// couvrent 7 m et plus (le seuil de hauteur minimal pour un abri hivernal
// selon le Forestier en chef) ; 5-7 couvrent moins de 7 m.
bool _hauteurSeptMetresPlus(String haut) {
  final n = int.tryParse(haut);
  return n != null && n <= 4;
}

/// Calcule le score d'habitat pour le chevreuil à partir des attributs
/// écoforestiers du MFFP (même schéma que CARTE_ECO_MAJ_PROV.gpkg).
///
/// `neighborProps` (optionnel) permet une détection d'écotone plus précise
/// en rut, en comparant le couvert du polygone aux polygones voisins.
HabitatScore scoreDeerHabitat(
  Map props,
  Season season, {
  List<Map>? neighborProps,
}) {
  final reasons = <String>[];

  final couv = (props['type_couv'] ?? '').toString().toUpperCase();
  final ess = (props['gr_ess'] ?? '').toString().toUpperCase();
  final origine = (props['origine'] ?? '').toString().toUpperCase();
  final age = (props['cl_age'] ?? '').toString().toUpperCase();
  final drai = (props['cl_drai'] ?? '').toString();
  final dens = (props['cl_dens'] ?? '').toString().toUpperCase();
  final haut = (props['cl_haut'] ?? '').toString();
  final pente = (props['cl_pent'] ?? '').toString().toUpperCase();
  final typeEco = (props['type_eco'] ?? '').toString().toUpperCase();
  final codeCouv = (props['code_couv'] ?? '').toString().toUpperCase();

  if (typeEco.contains('EAU') || codeCouv == 'EE' || typeEco.contains('URB')) {
    return HabitatScore.fromRaw(
      0,
      _maxForSeason(season),
      const ['Zone non forestière (eau ou milieu urbain)'],
    );
  }

  if (hasPreferredMast(props)) {
    reasons.add('🌰 Chêne rouge ou hêtre — glands/faînes, nourriture de prédilection');
  }

  int score = switch (season) {
    Season.preRut => _scorePreRut(couv, ess, origine, age, drai, dens, reasons),
    Season.rut => _scoreRut(couv, ess, age, dens, pente, reasons, neighborProps),
    Season.postRut =>
      _scorePostRut(couv, ess, age, dens, haut, drai, reasons, neighborProps),
  };

  if (typeEco.contains('AGR') || codeCouv.contains('AGR')) {
    score -= 2;
  }

  return HabitatScore.fromRaw(
    score.clamp(0, 999),
    _maxForSeason(season),
    reasons,
  );
}

int _scorePreRut(
  String couv,
  String ess,
  String origine,
  String age,
  String drai,
  String dens,
  List<String> reasons,
) {
  int score = 0;

  if (couv == 'F') {
    score += 4;
    reasons.add('Peuplement feuillu');
  } else if (couv == 'M') {
    score += 2;
    reasons.add('Peuplement mixte');
  }

  if (ess.contains('PE') || ess.contains('PT')) {
    score += 5;
    reasons.add('Tremble/peuplier — nourriture de prédilection en pré-rut');
  }
  if (ess.contains('BP') || ess.contains('BJ')) {
    score += 4;
    reasons.add('Bouleau — feuillage et brindilles appétents');
  }
  if (ess.contains('ER') || ess.contains('ES')) {
    score += 3;
    reasons.add('Érable — feuillage recherché');
  }
  if (ess.contains('FR') || ess.contains('FH')) {
    score += 3;
    reasons.add('Frêne — essence de nourriture reconnue (Forestier en chef)');
  }
  if (ess.contains('AU') || ess.contains('SA')) {
    score += 3;
    reasons.add('Aulnaie/saulaie — repousse arbustive');
  }

  final ageJeune = _isJeune(age);
  final coupeRecente = origine.contains('CP');
  if (coupeRecente && ageJeune) {
    score += 6;
    reasons.add('Coupe récente (3-10 ans) — régénération abondante');
  } else if (coupeRecente && age == '20') {
    score += 3;
    reasons.add('Coupe en régénération avancée');
  }

  if (dens == 'A' || dens == 'B') {
    score += 2;
    reasons.add('Couvert clairsemé — accès facile aux arbustes');
  }

  if (_isHumide(drai)) {
    score += 3;
    reasons.add('Milieu humide à proximité');
  }

  return score;
}

int _scoreRut(
  String couv,
  String ess,
  String age,
  String dens,
  String pente,
  List<String> reasons,
  List<Map>? neighborProps,
) {
  int score = 0;

  if (couv == 'M') {
    score += 5;
    reasons.add('Peuplement mixte — transition entre couverts');
  }

  if (neighborProps != null && neighborProps.isNotEmpty) {
    final types = neighborProps
        .map((p) => (p['type_couv'] ?? '').toString().toUpperCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    if (couv.isNotEmpty) types.add(couv);
    if (types.length > 1) {
      score += 6;
      reasons.add('Écotone — lisière entre peuplements voisins');
    }
  }

  if (pente == 'A' || pente == 'B') {
    score += 4;
    reasons.add('Topographie douce — corridor de déplacement facile');
  }

  if (dens == 'C' || dens == 'D') {
    score += 3;
    reasons.add('Couvert dense — sécurité pour les déplacements');
  }

  if (_isJeune(age) || age == '20') {
    score += 2;
    reasons.add('Jeune peuplement voisin — zone d\'alimentation pour les femelles');
  }

  if (ess.contains('PE') || ess.contains('PT') || ess.contains('BP')) {
    score += 2;
    reasons.add('Feuillus tendres présents — attire les femelles');
  }

  return score;
}

int _scorePostRut(
  String couv,
  String ess,
  String age,
  String dens,
  String haut,
  String drai,
  List<String> reasons,
  List<Map>? neighborProps,
) {
  int score = 0;

  if (ess.contains('SB')) {
    score += 5;
    reasons.add('Sapin baumier — couvert thermique hivernal');
  }
  if (ess.contains('TO')) {
    score += 5;
    reasons.add('Cèdre — ravage à chevreuils classique');
  }
  if (ess.contains('EN') || ess.contains('EB')) {
    score += 3;
    reasons.add('Épinette — essence de ravage (Forestier en chef)');
  }
  if (ess.contains('PE') || ess.contains('PT')) {
    score += 2;
    reasons.add('Tremble — écorce et brindilles disponibles en hiver');
  }

  // Seuil MFFP : fermeture de couvert résineux ≥ 70 % pour un abri hivernal.
  if (couv == 'R' && dens == 'D') {
    score += 6;
    reasons.add('Couvert résineux ≥ 80 % — dépasse le seuil MFFP de 70 % pour un ravage');
  } else if (couv == 'R' && dens == 'C') {
    score += 3;
    reasons.add('Couvert résineux modérément dense (60-79 %)');
  } else if (couv == 'R') {
    score += 1;
    reasons.add('Peuplement résineux — protection contre le froid et le vent');
  }

  if (couv == 'R' && _hauteurSeptMetresPlus(haut)) {
    score += 4;
    reasons.add('Hauteur ≥ 7 m — bonne interception de la neige (seuil MFFP)');
  }

  if (couv == 'R' && _isMature(age)) {
    score += 3;
    reasons.add('Peuplement mature à suranné — meilleure protection contre le vent et la neige');
  }

  if (drai.isNotEmpty && (drai[0] == '3' || drai[0] == '4')) {
    score += 2;
    reasons.add('Zone basse abritée');
  }

  // Entremêlement abri-nourriture (< 300-400 m selon le Forestier en chef).
  if (couv == 'R' && neighborProps != null && neighborProps.isNotEmpty) {
    final foodNearby = neighborProps.any((p) {
      final nCouv = (p['type_couv'] ?? '').toString().toUpperCase();
      final nAge = (p['cl_age'] ?? '').toString().toUpperCase();
      return nCouv == 'F' || nCouv == 'M' || _isJeune(nAge);
    });
    if (foodNearby) {
      score += 5;
      reasons.add('Nourriture feuillue à proximité — entremêlement abri-nourriture (< 400 m)');
    }
  }

  return score;
}
