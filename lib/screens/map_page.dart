import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/habitat_score.dart';
import '../models/score_level.dart';
import '../models/season.dart';
import '../services/deer_habitat_service.dart';
import '../services/deer_polygon_service.dart';
import '../services/eco_feature_parser.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  Season _season = Season.preRut;
  List<EcoFeature> _features = [];
  List<Polygon> _polygons = [];
  bool _loading = true;
  LatLngBounds? _bounds;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final jsonStr = await rootBundle.loadString('assets/sample_eco.geojson');
    final features = await compute(parseEcoFeaturesIsolate, jsonStr);
    setState(() {
      _features = features;
      _bounds = boundsFromFeatures(features);
      _polygons = buildDeerPolygons(features, _season);
      _loading = false;
    });
  }

  void _changeSeason(Season season) {
    setState(() {
      _season = season;
      _polygons = buildDeerPolygons(_features, _season);
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    final feature = findFeatureAtPoint(_features, point);
    if (feature == null) return;
    final score = scoreDeerHabitat(feature.props, _season);
    _showExplanationSheet(score);
  }

  void _showExplanationSheet(HabitatScore score) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: score.level.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    score.level.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (score.reasons.isEmpty)
                const Text('Aucune information disponible pour cette zone.')
              else
                ...score.reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(r)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: _bounds != null
                        ? CameraFit.bounds(bounds: _bounds!, padding: const EdgeInsets.all(24))
                        : null,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.chevreuilscan.chevreuilscan',
                    ),
                    PolygonLayer(polygons: _polygons),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: SafeArea(child: _SeasonSelector(season: _season, onChanged: _changeSeason)),
                ),
                const Positioned(
                  bottom: 16,
                  left: 12,
                  child: _Legend(),
                ),
              ],
            ),
    );
  }
}

class _SeasonSelector extends StatelessWidget {
  final Season season;
  final ValueChanged<Season> onChanged;

  const _SeasonSelector({required this.season, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SegmentedButton<Season>(
          segments: Season.values
              .map((s) => ButtonSegment(value: s, label: Text(s.label)))
              .toList(),
          selected: {season},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ScoreLevel.values
              .map((level) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, color: level.color),
                        const SizedBox(width: 6),
                        Text(level.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
