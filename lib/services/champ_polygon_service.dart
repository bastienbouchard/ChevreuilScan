import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/champ.dart';
import '../models/score_level.dart';
import '../models/season.dart';
import 'field_score_service.dart';

List<Polygon> buildChampPolygons(List<Champ> champs, Season season, DateTime now) {
  return champs.map((champ) {
    final score = scoreField(champ, season, now);
    return Polygon(
      points: champ.polygon,
      color: score.level.color.withValues(alpha: 0.6),
      borderColor: const Color(0xFF5D4037),
      borderStrokeWidth: 2,
    );
  }).toList();
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

Champ? findChampAtPoint(List<Champ> champs, LatLng point) {
  for (final champ in champs) {
    if (_pointInRing(point, champ.polygon)) return champ;
  }
  return null;
}
