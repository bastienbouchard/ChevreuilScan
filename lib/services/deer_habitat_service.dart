import '../models/habitat_score.dart';
import '../models/season.dart';

const int _maxPreRut = 30;
const int _maxRut = 22;
const int _maxPostRut = 26;

int _maxForSeason(Season season) => switch (season) {
      Season.preRut => _maxPreRut,
      Season.rut => _maxRut,
      Season.postRut => _maxPostRut,
    };

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

  int score = switch (season) {
    Season.preRut => _scorePreRut(couv, ess, origine, age, drai, dens, reasons),
    Season.rut => _scoreRut(couv, ess, age, dens, pente, reasons, neighborProps),
    Season.postRut => _scorePostRut(couv, ess, dens, drai, reasons),
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

  if (ess.contains('PE')) {
    score += 5;
    reasons.add('Tremble — nourriture de prédilection en pré-rut');
  }
  if (ess.contains('BP') || ess.contains('BJ')) {
    score += 4;
    reasons.add('Bouleau — feuillage et brindilles appétents');
  }
  if (ess.contains('ERR') || ess.contains('ERS')) {
    score += 3;
    reasons.add('Érable — feuillage recherché');
  }
  if (ess.contains('AU') || ess.contains('SA')) {
    score += 3;
    reasons.add('Aulnaie/saulaie — repousse arbustive');
  }

  final coupeJeune = origine == 'CP' && (age == '10' || age == 'J' || age == 'JIN');
  if (coupeJeune) {
    score += 6;
    reasons.add('Coupe récente (3-10 ans) — régénération abondante');
  } else if (origine == 'CP' && age == '20') {
    score += 3;
    reasons.add('Coupe en régénération avancée');
  }

  if (dens == 'A' || dens == 'B') {
    score += 2;
    reasons.add('Couvert clairsemé — accès facile aux arbustes');
  }

  if (drai == '4' || drai == '5' || drai == '6') {
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

  if (age == 'J' || age == 'JIN' || age == '10' || age == '20') {
    score += 2;
    reasons.add('Jeune peuplement voisin — zone d\'alimentation pour les femelles');
  }

  if (ess.contains('PE') || ess.contains('BP')) {
    score += 2;
    reasons.add('Feuillus tendres présents — attire les femelles');
  }

  return score;
}

int _scorePostRut(
  String couv,
  String ess,
  String dens,
  String drai,
  List<String> reasons,
) {
  int score = 0;

  if (ess.contains('SAB')) {
    score += 6;
    reasons.add('Sapin baumier — couvert thermique hivernal');
  }
  if (ess.contains('TO')) {
    score += 6;
    reasons.add('Cèdre — ravage à chevreuils classique');
  }
  if (ess.contains('PE')) {
    score += 3;
    reasons.add('Tremble — écorce et brindilles disponibles en hiver');
  }

  if (couv == 'R') {
    score += 4;
    reasons.add('Peuplement résineux — protection contre le froid et le vent');
  }

  if (dens == 'C' || dens == 'D') {
    score += 5;
    reasons.add('Couvert dense — zone de refuge hivernal');
  }

  if (drai == '3' || drai == '4') {
    score += 2;
    reasons.add('Zone basse abritée');
  }

  return score;
}
