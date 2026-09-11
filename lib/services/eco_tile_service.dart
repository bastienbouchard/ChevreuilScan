import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'eco_feature_parser.dart';
import 'gzip_helper.dart';

// Même bucket public R2 que EcoMap/OrignalScan — mêmes tuiles écoforestières
// MFFP (0.5° x 0.5°), généré depuis CARTE_ECO_MAJ_PROV.gpkg.
const _cdnBase = 'https://pub-5c51ef289e6943dbb647c2a2d1baa3bf.r2.dev';

String _tileName(double lat, double lon) {
  final latFloor = (lat * 2).floor() / 2;
  final lonFloor = (lon * 2).floor() / 2;
  final latInt = latFloor.floor();
  final latFrac = ((latFloor - latInt) * 10).round();
  final lonAbs = lonFloor.abs();
  final lonInt = lonAbs.floor();
  final lonFrac = ((lonAbs - lonInt) * 10).round();
  final lonSign = lon < 0 ? 'm' : '';
  return '${latInt}d${latFrac}_$lonSign${lonInt}d$lonFrac.geojson.gz';
}

List<String> tilesForBounds(LatLngBounds bounds) {
  final tiles = <String>[];
  var lat = (bounds.south * 2).floor() / 2.0;
  while (lat <= bounds.north) {
    var lon = (bounds.west * 2).floor() / 2.0;
    while (lon <= bounds.east) {
      tiles.add(_tileName(lat, lon));
      lon += 0.5;
    }
    lat += 0.5;
  }
  return tiles;
}

class EcoTileService {
  final Map<String, List<EcoFeature>> _cache = {};
  final Set<String> _missing = {};

  Future<List<EcoFeature>> loadForBounds(LatLngBounds bounds) async {
    final tiles = tilesForBounds(bounds);
    for (final tile in tiles) {
      if (_cache.containsKey(tile) || _missing.contains(tile)) continue;
      await _fetchTile(tile);
    }
    return [for (final tile in tiles) ...?_cache[tile]];
  }

  Future<void> _fetchTile(String tile) async {
    try {
      final resp = await http
          .get(Uri.parse('$_cdnBase/$tile'))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 404) {
        _missing.add(tile);
        return;
      }
      if (resp.statusCode != 200) return;

      String jsonStr;
      try {
        jsonStr = await decompressGzip(resp.bodyBytes);
      } catch (_) {
        jsonStr = utf8.decode(resp.bodyBytes);
      }
      final features = await compute(parseEcoFeaturesIsolate, jsonStr);
      _cache[tile] = features;
    } catch (_) {
      // Échec réseau ponctuel : on réessaiera au prochain déplacement de la carte.
    }
  }
}
