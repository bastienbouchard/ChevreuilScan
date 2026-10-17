import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/season.dart';
import 'deer_habitat_service.dart';
import 'eco_feature_parser.dart';

class StandRecommendation {
  final int rank;
  final LatLng position;
  final LatLng targetZone;
  final String reason;

  const StandRecommendation({
    required this.rank,
    required this.position,
    required this.targetZone,
    required this.reason,
  });
}

LatLng _centroid(List<LatLng> ring) {
  double sumLat = 0, sumLon = 0;
  for (final p in ring) {
    sumLat += p.latitude;
    sumLon += p.longitude;
  }
  return LatLng(sumLat / ring.length, sumLon / ring.length);
}

/// Déplace un point de [distanceM] mètres dans la direction [bearingDeg]
/// (0° = nord, sens horaire), selon un cercle de la Terre approximé en sphère.
LatLng _offset(LatLng from, double bearingDeg, double distanceM) {
  const earthRadius = 6371000.0;
  final bearing = bearingDeg * pi / 180;
  final lat1 = from.latitude * pi / 180;
  final lon1 = from.longitude * pi / 180;
  final angularDist = distanceM / earthRadius;

  final lat2 = asin(
    sin(lat1) * cos(angularDist) + cos(lat1) * sin(angularDist) * cos(bearing),
  );
  final lon2 = lon1 +
      atan2(
        sin(bearing) * sin(angularDist) * cos(lat1),
        cos(angularDist) - sin(lat1) * sin(lat2),
      );

  return LatLng(lat2 * 180 / pi, lon2 * 180 / pi);
}

/// Distance approximative en mètres entre deux points (haversine).
double _distanceM(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = (b.latitude - a.latitude) * pi / 180;
  final dLon = (b.longitude - a.longitude) * pi / 180;
  final lat1 = a.latitude * pi / 180;
  final lat2 = b.latitude * pi / 180;
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * earthRadius * asin(sqrt(h));
}

String _seasonZoneLabel(Season season) => switch (season) {
      Season.preRut => 'zone de nourriture feuillue (pré-rut)',
      Season.rut => 'écotone/corridor actif (rut)',
      Season.postRut => 'zone de refuge et de couvert dense (post-rut)',
    };

/// Recommande jusqu'à [maxResults] emplacements de poste d'affût à partir
/// des polygones actuellement visibles sur la carte (donc adapté au zoom et
/// au déplacement de l'utilisateur) : prend les meilleures zones d'habitat
/// pour la saison, assez éloignées les unes des autres pour être de vrais
/// choix distincts, puis positionne chaque poste sous le vent (odeur du
/// chasseur emportée à l'opposé de la zone), à [standDistanceM] mètres de
/// son centre.
List<StandRecommendation> findBestStands({
  required List<EcoFeature> features,
  required Season season,
  required double windFromDeg,
  double standDistanceM = 45,
  int maxResults = 3,
  double minSeparationM = 150,
}) {
  final scored = <MapEntry<EcoFeature, int>>[];
  for (final feature in features) {
    if (feature.rings.isEmpty) continue;
    final score = scoreDeerHabitat(feature.props, season).value;
    if (score > 0) scored.add(MapEntry(feature, score));
  }
  scored.sort((a, b) => b.value.compareTo(a.value));

  final standBearing = (windFromDeg + 180) % 360;
  final results = <StandRecommendation>[];
  for (final entry in scored) {
    final target = _centroid(entry.key.rings.first);
    final tooClose = results.any((r) => _distanceM(r.targetZone, target) < minSeparationM);
    if (tooClose) continue;

    final standPos = _offset(target, standBearing, standDistanceM);
    results.add(StandRecommendation(
      rank: results.length + 1,
      position: standPos,
      targetZone: target,
      reason: 'Poste positionné sous le vent d\'une ${_seasonZoneLabel(season)}, '
          'pour que ton odeur ne porte pas vers la zone.',
    ));
    if (results.length >= maxResults) break;
  }
  return results;
}
