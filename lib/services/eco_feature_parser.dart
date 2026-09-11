import 'dart:convert';
import 'package:latlong2/latlong.dart';

class EcoFeature {
  final Map<String, dynamic> props;
  final List<List<LatLng>> rings;

  const EcoFeature({required this.props, required this.rings});
}

/// Parse le GeoJSON écoforestier en isolate séparé (fichier de plusieurs Mo).
List<EcoFeature> parseEcoFeaturesIsolate(String jsonStr) {
  final data = json.decode(jsonStr) as Map<String, dynamic>;
  final features = data['features'] as List;
  final result = <EcoFeature>[];

  for (final feat in features) {
    try {
      final props = Map<String, dynamic>.from(feat['properties'] as Map);
      final geom = feat['geometry'] as Map;
      final type = geom['type'];
      final rings = <List<LatLng>>[];

      List<LatLng> toRing(List coords) =>
          coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

      if (type == 'Polygon') {
        for (final ring in geom['coordinates'] as List) {
          rings.add(toRing(ring as List));
        }
      } else if (type == 'MultiPolygon') {
        for (final poly in geom['coordinates'] as List) {
          for (final ring in poly as List) {
            rings.add(toRing(ring as List));
          }
        }
      } else {
        continue;
      }

      result.add(EcoFeature(props: props, rings: rings));
    } catch (_) {}
  }

  return result;
}
