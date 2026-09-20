import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/season.dart';
import 'deer_habitat_service.dart';
import 'eco_feature_parser.dart';

class StandRecommendation {
  final LatLng position;
  final LatLng targetZone;
  final String reason;

  const StandRecommendation({
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

String _seasonZoneLabel(Season season) => switch (season) {
      Season.preRut => 'zone de nourriture feuillue (pré-rut)',
      Season.rut => 'écotone/corridor actif (rut)',
      Season.postRut => 'zone de refuge et de couvert dense (post-rut)',
    };

/// Recommande un emplacement de poste d'affût à partir des polygones
/// actuellement chargés : trouve la meilleure zone d'habitat pour la saison,
/// puis positionne le poste sous le vent (odeur du chasseur emportée à
/// l'opposé de la zone), à [standDistanceM] mètres de son centre.
StandRecommendation? findBestStand({
  required List<EcoFeature> features,
  required Season season,
  required double windFromDeg,
  double standDistanceM = 45,
}) {
  EcoFeature? best;
  var bestScore = -1;
  for (final feature in features) {
    if (feature.rings.isEmpty) continue;
    final score = scoreDeerHabitat(feature.props, season).value;
    if (score > bestScore) {
      bestScore = score;
      best = feature;
    }
  }
  if (best == null || bestScore <= 0) return null;

  final target = _centroid(best.rings.first);
  final standBearing = (windFromDeg + 180) % 360;
  final standPos = _offset(target, standBearing, standDistanceM);

  return StandRecommendation(
    position: standPos,
    targetZone: target,
    reason: 'Poste positionné sous le vent d\'une ${_seasonZoneLabel(season)}, '
        'pour que ton odeur ne porte pas vers la zone.',
  );
}
