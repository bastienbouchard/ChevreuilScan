import 'package:latlong2/latlong.dart';

import 'eco_feature_parser.dart';

class EcoLabel {
  final LatLng position;
  final String label;
  final String full;
  final int minZoom;

  const EcoLabel({
    required this.position,
    required this.label,
    required this.full,
    required this.minZoom,
  });
}

const _essNoms = {
  'EN': 'Épinette noire', 'EB': 'Épinette blanche', 'EP': 'Épinette rouge',
  'EU': 'Épinette', 'EO': 'Épinette noire ouverte', 'EV': 'Épinette variée',
  'SB': 'Sapin baumier', 'SE': 'Sapin-Épinette',
  'TO': 'Thuya occidental', 'ML': 'Mélèze laricin',
  'PG': 'Pin gris', 'PI': 'Pin blanc', 'PR': 'Pin rouge', 'PU': 'Pruche',
  'BJ': 'Bouleau jaune', 'BP': 'Bouleau blanc',
  'PE': 'Peuplier faux-tremble', 'PB': 'Peuplier baumier',
  'PT': 'Peuplier à grandes dents', 'PA': 'Peuplier hybride',
  'ER': 'Érable rouge', 'ES': 'Érable à sucre',
  'FT': 'Feuillus tolérants', 'FI': 'Feuillus intolérants',
  'FN': 'Feuillus nordiques', 'FX': 'Feuillus mixtes',
  'FH': 'Frêne noir', 'FR': 'Frêne rouge',
  'RX': 'Résineux mixtes', 'RZ': 'Régénération résineuse',
  'EA': 'Aulne', 'HG': 'Herbacées', 'CR': 'Cerisier',
  'FO': 'Forêt ouverte', 'FZ': 'Forêt en régénération',
};

const _essAbbrev = {
  'EN': 'Én', 'EB': 'Éb', 'EP': 'Ér', 'EU': 'É', 'EO': 'Éo',
  'SB': 'Sa', 'SE': 'Sa-É',
  'TO': 'Th', 'ML': 'Mé',
  'PG': 'Pg', 'PI': 'Pi', 'PR': 'Pr', 'PU': 'Pu',
  'BJ': 'Bj', 'BP': 'Bb',
  'PE': 'Pt', 'PB': 'Pb', 'PT': 'Pgd', 'PA': 'Pa',
  'ER': 'Ear', 'ES': 'Eas',
  'FT': 'Ft', 'FI': 'Fi', 'FN': 'Fn', 'FX': 'Fx',
  'RX': 'Rx', 'RZ': 'Rz', 'EA': 'Aul', 'HG': 'Hb',
};

const _densNoms = {
  'A': '10-39 %', 'B': '40-59 %', 'C': '60-79 %', 'D': '80-100 %',
};

final _rDigits = RegExp(r'^\d+$');
final _r4Digits = RegExp(r'^\d{4}$');
const _ageNoms = {
  'JIN': 'Jeune irrég.', 'JIR': 'Jeune irrég.',
  'VIN': 'Vieux irrég.', 'VIR': 'Vieux irrég.',
};

List<String> _splitGrEss(String grEss) {
  final parts = <String>[];
  for (var i = 0; i + 1 < grEss.length; i += 2) {
    parts.add(grEss.substring(i, i + 2));
  }
  return parts;
}

String _decodeGrEss(String grEss) => _splitGrEss(grEss).map((c) => _essNoms[c] ?? c).join(' · ');

String _abbreviateGrEss(String grEss) =>
    _splitGrEss(grEss).map((c) => _essAbbrev[c] ?? c).join('-');

String _decodeAge(String age) {
  if (age.isEmpty) return '';
  if (_rDigits.hasMatch(age)) return '$age ans';
  if (_r4Digits.hasMatch(age)) return '${age.substring(0, 2)} ans / ${age.substring(2)} ans';
  return _ageNoms[age] ?? age;
}

/// Étiquettes essence/âge à afficher sur la carte à fort zoom (ex. "Pt-Bj").
List<EcoLabel> buildEcoLabels(List<EcoFeature> features) {
  final result = <EcoLabel>[];
  for (final feature in features) {
    final ess = (feature.props['gr_ess'] ?? '').toString();
    if (ess.isEmpty || feature.rings.isEmpty) continue;
    final age = (feature.props['cl_age'] ?? '').toString();
    final dens = (feature.props['cl_dens'] ?? '').toString();
    final ring = feature.rings.first;

    double sumLat = 0, sumLon = 0;
    double minLon = double.infinity, maxLon = -double.infinity;
    double minLat = double.infinity, maxLat = -double.infinity;
    for (final p in ring) {
      sumLat += p.latitude;
      sumLon += p.longitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
    }
    final extent = (maxLon - minLon) + (maxLat - minLat);
    final minZoom = extent > 0.003 ? 14 : 16;

    final full = _decodeGrEss(ess) +
        (age.isNotEmpty ? '\n${_decodeAge(age)}' : '') +
        (dens.isNotEmpty ? ' · Densité ${_densNoms[dens] ?? dens}' : '');

    result.add(EcoLabel(
      position: LatLng(sumLat / ring.length, sumLon / ring.length),
      label: _abbreviateGrEss(ess),
      full: full,
      minZoom: minZoom,
    ));
  }
  return result;
}
