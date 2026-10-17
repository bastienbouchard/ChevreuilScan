import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/season.dart';

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

/// Une zone candidate pour un poste d'affût — peuplement forestier ou champ
/// agricole, peu importe : seul compte le ratio de score (0-1, comparable
/// entre les deux systèmes de scoring) et le centroïde.
class StandCandidate {
  final LatLng centroid;
  final double ratio;
  final String zoneLabel;

  const StandCandidate({required this.centroid, required this.ratio, required this.zoneLabel});
}

LatLng centroidOfRing(List<LatLng> ring) {
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

/// Texte décrivant le type de zone forestière pour une saison donnée —
/// réutilisé par l'appelant pour construire les candidats issus de l'habitat
/// forestier (par opposition aux champs, qui ont leur propre libellé).
String seasonZoneLabel(Season season) => switch (season) {
      Season.preRut => 'zone de nourriture feuillue (pré-rut)',
      Season.rut => 'écotone/corridor actif (rut)',
      Season.postRut => 'zone de refuge et de couvert dense (post-rut)',
    };

/// Recommande jusqu'à [maxResults] emplacements de poste d'affût à partir des
/// zones candidates fournies (peuplements forestiers ET champs agricoles
/// confondus — à l'appelant de construire la liste) : prend les meilleures,
/// assez éloignées les unes des autres pour être de vrais choix distincts,
/// puis positionne chaque poste sous le vent (odeur du chasseur emportée à
/// l'opposé de la zone), à [standDistanceM] mètres de son centre.
List<StandRecommendation> findBestStands({
  required List<StandCandidate> candidates,
  required double windFromDeg,
  double standDistanceM = 45,
  int maxResults = 3,
  double minSeparationM = 150,
}) {
  final sorted = [...candidates]..sort((a, b) => b.ratio.compareTo(a.ratio));

  final standBearing = (windFromDeg + 180) % 360;
  final results = <StandRecommendation>[];
  for (final candidate in sorted) {
    if (candidate.ratio <= 0) continue;
    final tooClose =
        results.any((r) => _distanceM(r.targetZone, candidate.centroid) < minSeparationM);
    if (tooClose) continue;

    final standPos = _offset(candidate.centroid, standBearing, standDistanceM);
    results.add(StandRecommendation(
      rank: results.length + 1,
      position: standPos,
      targetZone: candidate.centroid,
      reason: 'Poste positionné sous le vent d\'une ${candidate.zoneLabel}, '
          'pour que ton odeur ne porte pas vers la zone.',
    ));
    if (results.length >= maxResults) break;
  }
  return results;
}
