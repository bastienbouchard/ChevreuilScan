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

LatLngBounds boundsFromFeatures(List<EcoFeature> features) {
  double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
  for (final feature in features) {
    for (final ring in feature.rings) {
      for (final p in ring) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
    }
  }
  return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
}
