import 'dart:async';

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
import '../services/eco_tile_service.dart';
import '../services/field_score_service.dart';
import '../widgets/champ_form_sheet.dart';

// Au-delà de ce nombre de tuiles (0.5° x 0.5° chacune) visibles à l'écran,
// on demande à l'utilisateur de zoomer plutôt que de tout télécharger.
const _maxVisibleTiles = 6;
const _initialCenter = LatLng(48.2917, -71.322);
const _initialZoom = 12.0;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final EcoTileService _tileService = EcoTileService();

  Season _season = Season.preRut;
  List<EcoFeature> _features = [];
  List<EcoFeature> _ravages = [];
  List<Champ> _champs = [];
  List<Polygon> _polygons = [];
  List<Polygon> _ravagePolygons = [];
  List<Polygon> _champPolygons = [];
  bool _loading = true;
  bool _loadingTiles = false;
  bool _tooZoomedOut = false;

  bool _drawingField = false;
  List<LatLng> _drawingPoints = [];
  Timer? _moveSettleTimer;

  // Couche de fond et sources satellite/topo — même principe qu'EcoMap.
  String _baseLayer = 'osm'; // 'osm' | 'satellite' | 'topo'
  String _satSource = 'esri'; // 'esri' | 'sentinel' | 'mern'
  bool _ecoVisible = true;
  double _ecoOpacity = 0.55;
  bool _showLayerPanel = false;

  String _tileUrlTemplate() {
    switch (_baseLayer) {
      case 'satellite':
        switch (_satSource) {
          case 'sentinel':
            return 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2023_3857/default/g/{z}/{y}/{x}.jpg';
          case 'mern':
            return 'https://servicesmatriciels.mern.gouv.qc.ca/erdas-iws/ogc/wmts/Imagerie_Continue'
                '?layer=Imagerie_GQ&style=default&tilematrixset=GoogleMapsCompatibleExt2:epsg:3857'
                '&Service=WMTS&Request=GetTile&Version=1.0.0&Format=image/jpeg'
                '&TileMatrix={z}&TileCol={x}&TileRow={y}';
          case 'esri':
          default:
            return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
        }
      case 'topo':
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      case 'osm':
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _moveSettleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final ravageJson = await rootBundle.loadString('assets/ravages_cerf.geojson');
    final ravages = await compute(parseEcoFeaturesIsolate, ravageJson);
    final champs = await loadChamps();
    setState(() {
      _ravages = ravages;
      _champs = champs;
      _ravagePolygons = buildRavagePolygons(ravages);
      _champPolygons = buildChampPolygons(champs, _season, DateTime.now());
      _loading = false;
    });
  }

  Future<void> _loadVisibleTiles() async {
    final bounds = _mapController.camera.visibleBounds;
    final tileCount = tilesForBounds(bounds).length;
    if (tileCount > _maxVisibleTiles) {
      setState(() => _tooZoomedOut = true);
      return;
    }
    setState(() {
      _tooZoomedOut = false;
      _loadingTiles = true;
    });
    final features = await _tileService.loadForBounds(bounds);
    if (!mounted) return;
    setState(() {
      _features = features;
      _polygons = buildDeerPolygons(features, _season);
      _loadingTiles = false;
    });
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _moveSettleTimer?.cancel();
    _moveSettleTimer = Timer(const Duration(milliseconds: 500), _loadVisibleTiles);
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
                    initialCenter: _initialCenter,
                    initialZoom: _initialZoom,
                    onTap: _onMapTap,
                    onPositionChanged: _onMapPositionChanged,
                    onMapReady: _loadVisibleTiles,
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey('$_baseLayer-$_satSource'),
                      urlTemplate: _tileUrlTemplate(),
                      userAgentPackageName: 'com.bastienbouchard.chevreuilscan',
                      maxZoom: 22,
                    ),
                    if (_ecoVisible)
                      Opacity(
                        opacity: _ecoOpacity,
                        child: PolygonLayer(polygons: _polygons),
                      ),
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
                  child: SafeArea(
                    child: Column(
                      children: [
                        _SeasonSelector(season: _season, onChanged: _changeSeason),
                        if (_tooZoomedOut) ...[
                          const SizedBox(height: 8),
                          const _InfoBanner(text: 'Zoome pour voir la carte d\'habitat'),
                        ] else if (_loadingTiles) ...[
                          const SizedBox(height: 8),
                          const _InfoBanner(text: 'Chargement de l\'habitat…', showSpinner: true),
                        ],
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  left: 12,
                  child: _Legend(),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.42,
                        child: Image.asset('assets/logo.png', width: 90),
                      ),
                    ),
                  ),
                ),
                if (_showLayerPanel)
                  Positioned(
                    top: 70,
                    right: 12,
                    child: SafeArea(
                      child: _LayerPanel(
                        baseLayer: _baseLayer,
                        satSource: _satSource,
                        ecoVisible: _ecoVisible,
                        ecoOpacity: _ecoOpacity,
                        onBaseLayerChanged: (v) => setState(() => _baseLayer = v),
                        onSatSourceChanged: (v) => setState(() => _satSource = v),
                        onEcoToggle: () => setState(() => _ecoVisible = !_ecoVisible),
                        onEcoOpacityChanged: (v) => setState(() => _ecoOpacity = v),
                      ),
                    ),
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
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'layers',
                  onPressed: () => setState(() => _showLayerPanel = !_showLayerPanel),
                  tooltip: 'Couches de carte',
                  backgroundColor: _showLayerPanel ? Theme.of(context).colorScheme.primaryContainer : null,
                  child: const Icon(Icons.layers_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'draw',
                  onPressed: _toggleDrawing,
                  tooltip: 'Dessiner un champ',
                  child: const Icon(Icons.agriculture),
                ),
              ],
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

class _InfoBanner extends StatelessWidget {
  final String text;
  final bool showSpinner;

  const _InfoBanner({required this.text, this.showSpinner = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _LayerPanel extends StatelessWidget {
  final String baseLayer;
  final String satSource;
  final bool ecoVisible;
  final double ecoOpacity;
  final ValueChanged<String> onBaseLayerChanged;
  final ValueChanged<String> onSatSourceChanged;
  final VoidCallback onEcoToggle;
  final ValueChanged<double> onEcoOpacityChanged;

  const _LayerPanel({
    required this.baseLayer,
    required this.satSource,
    required this.ecoVisible,
    required this.ecoOpacity,
    required this.onBaseLayerChanged,
    required this.onSatSourceChanged,
    required this.onEcoToggle,
    required this.onEcoOpacityChanged,
  });

  Widget _baseChoice(BuildContext context, String value, String label, IconData icon) {
    final selected = baseLayer == value;
    return InkWell(
      onTap: () => onBaseLayerChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Theme.of(context).colorScheme.primary : null),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _satChip(String value, String label) {
    final selected = satSource == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onSatSourceChanged(value),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fond de carte', style: Theme.of(context).textTheme.labelLarge),
            _baseChoice(context, 'osm', 'Carte', Icons.map_outlined),
            _baseChoice(context, 'satellite', 'Satellite', Icons.satellite_alt_outlined),
            if (baseLayer == 'satellite')
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 4, bottom: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _satChip('esri', 'ESRI'),
                    _satChip('sentinel', 'Sentinel'),
                    _satChip('mern', 'MRNF QC'),
                  ],
                ),
              ),
            _baseChoice(context, 'topo', 'Topographique', Icons.terrain_outlined),
            const Divider(height: 20),
            InkWell(
              onTap: onEcoToggle,
              child: Row(
                children: [
                  Icon(
                    ecoVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Carte d\'habitat')),
                  Text('${(ecoOpacity * 100).round()}%', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (ecoVisible)
              Slider(
                value: ecoOpacity,
                min: 0.05,
                max: 1.0,
                onChanged: onEcoOpacityChanged,
              ),
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
