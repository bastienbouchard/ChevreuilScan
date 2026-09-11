import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/champ.dart';
import '../models/habitat_score.dart';
import '../models/score_level.dart';
import '../models/season.dart';
import '../services/champ_polygon_service.dart';
import '../services/champ_storage_service.dart';
import '../services/deer_habitat_service.dart';
import '../services/deer_polygon_service.dart';
import '../services/eco_feature_parser.dart';
import '../services/field_score_service.dart';
import '../widgets/champ_form_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  Season _season = Season.preRut;
  List<EcoFeature> _features = [];
  List<EcoFeature> _ravages = [];
  List<Champ> _champs = [];
  List<Polygon> _polygons = [];
  List<Polygon> _ravagePolygons = [];
  List<Polygon> _champPolygons = [];
  bool _loading = true;
  LatLngBounds? _bounds;

  bool _drawingField = false;
  List<LatLng> _drawingPoints = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ecoJson = await rootBundle.loadString('assets/sample_eco.geojson');
    final ravageJson = await rootBundle.loadString('assets/ravages_cerf.geojson');
    final features = await compute(parseEcoFeaturesIsolate, ecoJson);
    final ravages = await compute(parseEcoFeaturesIsolate, ravageJson);
    final champs = await loadChamps();
    setState(() {
      _features = features;
      _ravages = ravages;
      _champs = champs;
      _bounds = boundsFromFeatures(features);
      _polygons = buildDeerPolygons(features, _season);
      _ravagePolygons = buildRavagePolygons(ravages);
      _champPolygons = buildChampPolygons(champs, _season, DateTime.now());
      _loading = false;
    });
  }

  void _changeSeason(Season season) {
    setState(() {
      _season = season;
      _polygons = buildDeerPolygons(_features, _season);
      _champPolygons = buildChampPolygons(_champs, _season, DateTime.now());
    });
  }

  void _toggleDrawing() {
    setState(() {
      _drawingField = !_drawingField;
      _drawingPoints = [];
    });
  }

  Future<void> _finishDrawing() async {
    if (_drawingPoints.length < 3) return;
    final points = List<LatLng>.from(_drawingPoints);
    setState(() {
      _drawingField = false;
      _drawingPoints = [];
    });
    final champ = await showChampFormSheet(context, points);
    if (champ == null) return;
    setState(() {
      _champs = [..._champs, champ];
      _champPolygons = buildChampPolygons(_champs, _season, DateTime.now());
    });
    await saveChamps(_champs);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_drawingField) {
      setState(() => _drawingPoints = [..._drawingPoints, point]);
      return;
    }

    final champ = findChampAtPoint(_champs, point);
    if (champ != null) {
      final score = scoreField(champ, _season, DateTime.now());
      _showExplanationSheet(score, null, subtitle: champ.crop.label);
      return;
    }

    final feature = findFeatureAtPoint(_features, point);
    if (feature == null) return;
    final score = scoreDeerHabitat(feature.props, _season);
    final ravage = findFeatureAtPoint(_ravages, point);
    _showExplanationSheet(score, ravage);
  }

  void _showExplanationSheet(HabitatScore score, EcoFeature? ravage, {String? subtitle}) {
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
                    subtitle != null ? '${score.level.label} — $subtitle' : score.level.label,
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
              if (ravage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                    border: Border.all(color: const Color(0xFF6A1B9A)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.gavel, size: 18, color: Color(0xFF6A1B9A)),
                          SizedBox(width: 6),
                          Text(
                            'Ravage légal (MFFP)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aire de confinement officielle du cerf de Virginie'
                        '${ravage.props['TOPONYME'] != null ? ' — ${ravage.props['TOPONYME']}' : ''}. '
                        'Certaines activités y sont légalement restreintes du 1er décembre au 1er mai. '
                        'Vérifie la réglementation applicable avant de chasser dans ce secteur.',
                      ),
                    ],
                  ),
                ),
              ],
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
                    PolygonLayer(polygons: _ravagePolygons),
                    PolygonLayer(polygons: _champPolygons),
                    if (_drawingPoints.isNotEmpty) ...[
                      PolylineLayer(polylines: [
                        Polyline(points: _drawingPoints, color: const Color(0xFF5D4037), strokeWidth: 3),
                      ]),
                      CircleLayer(circles: [
                        for (final p in _drawingPoints)
                          CircleMarker(point: p, radius: 5, color: const Color(0xFF5D4037)),
                      ]),
                    ],
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
                if (_drawingField)
                  Positioned(
                    bottom: 16,
                    left: 12,
                    right: 12,
                    child: SafeArea(
                      child: _DrawingToolbar(
                        pointCount: _drawingPoints.length,
                        onCancel: _toggleDrawing,
                        onFinish: _drawingPoints.length >= 3 ? _finishDrawing : null,
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _loading || _drawingField
          ? null
          : FloatingActionButton(
              onPressed: _toggleDrawing,
              tooltip: 'Dessiner un champ',
              child: const Icon(Icons.agriculture),
            ),
    );
  }
}

class _DrawingToolbar extends StatelessWidget {
  final int pointCount;
  final VoidCallback onCancel;
  final VoidCallback? onFinish;

  const _DrawingToolbar({required this.pointCount, required this.onCancel, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                pointCount < 3
                    ? 'Touche la carte pour ajouter des points ($pointCount/3 min.)'
                    : '$pointCount points — prêt à terminer',
              ),
            ),
            TextButton(onPressed: onCancel, child: const Text('Annuler')),
            FilledButton(onPressed: onFinish, child: const Text('Terminer')),
          ],
        ),
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
              .toList()
            ..add(Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF6A1B9A), width: 2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Ravage légal (MFFP)', style: TextStyle(fontSize: 12)),
                ],
              ),
            )),
        ),
      ),
    );
  }
}
