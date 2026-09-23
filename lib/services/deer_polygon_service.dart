import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/score_level.dart';
import '../models/season.dart';
import 'deer_habitat_service.dart';
import 'eco_feature_parser.dart';

List<Polygon> buildDeerPolygons(List<EcoFeature> features, Season season) {
  final result = <Polygon>[];
  for (final feature in features) {
    final score = scoreDeerHabitat(feature.props, season);
    final color = score.level.color.withValues(alpha: 0.55);
    for (final ring in feature.rings) {
      result.add(Polygon(
        points: ring,
        color: color,
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      ));
    }
  }
  return result;
}

/// Centroïdes des peuplements contenant du chêne rouge ou du hêtre à
/// grandes feuilles (glands/faînes — nourriture de prédilection).
List<LatLng> mastMarkerPositions(List<EcoFeature> features) {
  final result = <LatLng>[];
  for (final feature in features) {
    if (feature.rings.isEmpty || !hasPreferredMast(feature.props)) continue;
    final ring = feature.rings.first;
    double sumLat = 0, sumLon = 0;
    for (final p in ring) {
      sumLat += p.latitude;
      sumLon += p.longitude;
    }
    result.add(LatLng(sumLat / ring.length, sumLon / ring.length));
  }
  return result;
}

bool _pointInRing(LatLng point, List<LatLng> ring) {
  bool inside = false;
  final x = point.longitude, y = point.latitude;
  var j = ring.length - 1;
  for (var i = 0; i < ring.length; i++) {
    final xi = ring[i].longitude, yi = ring[i].latitude;
    final xj = ring[j].longitude, yj = ring[j].latitude;
    if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
    j = i;
  }
  return inside;
}

EcoFeature? findFeatureAtPoint(List<EcoFeature> features, LatLng point) {
  for (final feature in features) {
    for (final ring in feature.rings) {
      if (_pointInRing(point, ring)) return feature;
    }
  }
  return null;
}
