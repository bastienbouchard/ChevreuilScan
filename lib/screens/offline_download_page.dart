import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/downloaded_zone.dart';
import '../services/eco_tile_service.dart';
import '../services/tile_cache_service.dart';

const _ecoMaxTiles = 12;
const _rasterMaxTilesPerLayer = 4000;
const _rasterMinZoom = 10;
const _rasterMaxZoom = 14;
const _insetMargin = 28.0;
const _previewUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class _RasterLayerOption {
  final String id;
  final String label;
  final String urlTemplate;
  const _RasterLayerOption(this.id, this.label, this.urlTemplate);
}

const _rasterLayers = [
  _RasterLayerOption('satellite', 'Satellite',
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
  _RasterLayerOption('topo', 'Topographique', 'https://tile.opentopomap.org/{z}/{x}/{y}.png'),
];

class OfflineDownloadPage extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final EcoTileService tileService;
  final List<DownloadedZone> zones;
  final ValueChanged<DownloadedZone> onZoneDownloaded;
  final ValueChanged<DownloadedZone> onZoneDeleted;

  const OfflineDownloadPage({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    required this.tileService,
    required this.zones,
    required this.onZoneDownloaded,
    required this.onZoneDeleted,
  });

  @override
  State<OfflineDownloadPage> createState() => _OfflineDownloadPageState();
}

class _OfflineDownloadPageState extends State<OfflineDownloadPage> {
  final _mapController = MapController();
  final Set<String> _selectedLayerIds = {'satellite'};
  bool _downloading = false;
  bool _done = false;
  String _status = '';
  double? _progress;
  LatLngBounds? _lastBounds;

  LatLngBounds _insetBounds(LatLngBounds full, Size widgetSize) {
    final fracX = _insetMargin / widgetSize.width;
    final fracY = _insetMargin / widgetSize.height;
    final lonSpan = full.east - full.west;
    final latSpan = full.north - full.south;
    return LatLngBounds(
      LatLng(full.south + latSpan * fracY, full.west + lonSpan * fracX),
      LatLng(full.north - latSpan * fracY, full.east - lonSpan * fracX),
    );
  }

  Future<void> _startDownload(LatLngBounds insetBounds) async {
    final ecoTiles = tilesForBounds(insetBounds);
    if (ecoTiles.length > _ecoMaxTiles) {
      _showSnack('Zone trop grande — zoome sur ton secteur de chasse précis avant de télécharger.');
      return;
    }
    final selectedLayers = _rasterLayers.where((l) => _selectedLayerIds.contains(l.id)).toList();
    final estimates = <String, int>{};
    for (final layer in selectedLayers) {
      final count = TileCacheService.instance.estimateTileCount(
        south: insetBounds.south,
        west: insetBounds.west,
        north: insetBounds.north,
        east: insetBounds.east,
        minZoom: _rasterMinZoom,
        maxZoom: _rasterMaxZoom,
      );
      if (count > _rasterMaxTilesPerLayer) {
        _showSnack('Zone trop grande pour la carte ${layer.label} — zoome davantage.');
        return;
      }
      estimates[layer.id] = count;
    }

    final nom = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Nom du territoire'),
          content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Ex. Secteur du lac...')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.of(context).pop(ctrl.text.trim()), child: const Text('Télécharger')),
          ],
        );
      },
    );
    if (nom == null || nom.isEmpty || !mounted) return;

    setState(() {
      _downloading = true;
      _done = false;
      _progress = null;
      _status = 'Téléchargement de la carte éco...';
    });

    var ecoDone = 0;
    for (final tile in ecoTiles) {
      await widget.tileService.downloadTileForOffline(tile);
      ecoDone++;
      if (!mounted) return;
      setState(() => _status = 'Carte éco : tuile $ecoDone/${ecoTiles.length}');
    }

    var rasterTotal = 0;
    for (final layer in selectedLayers) {
      await TileCacheService.instance.downloadTiles(
        urlTemplate: layer.urlTemplate,
        south: insetBounds.south,
        west: insetBounds.west,
        north: insetBounds.north,
        east: insetBounds.east,
        minZoom: _rasterMinZoom,
        maxZoom: _rasterMaxZoom,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progress = total == 0 ? 1 : done / total;
            _status = '${layer.label} : tuile $done/$total';
          });
        },
      );
      rasterTotal += estimates[layer.id] ?? 0;
    }

    final zone = DownloadedZone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nom: nom,
      date: DateTime.now(),
      tileCountEco: ecoTiles.length,
      tileCountRaster: rasterTotal,
      layers: ['Carte éco', ...selectedLayers.map((l) => l.label)],
    );
    widget.onZoneDownloaded(zone);

    if (!mounted) return;
    setState(() {
      _downloading = false;
      _done = true;
      _status = 'Territoire "$nom" téléchargé et disponible hors ligne.';
    });
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prépare ton territoire de chasse')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Déplace et zoome la carte pour cadrer le secteur à télécharger, '
            'à l\'intérieur du cadre orange.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: widget.initialCenter,
                          initialZoom: widget.initialZoom,
                          onPositionChanged: (camera, _) {
                            _lastBounds = camera.visibleBounds;
                          },
                        ),
                        children: [
                          TileLayer(urlTemplate: _previewUrlTemplate, userAgentPackageName: 'com.bastienbouchard.chevreuilscan'),
                        ],
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(_insetMargin),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('Cartes à inclure', style: TextStyle(fontWeight: FontWeight.bold)),
          const CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: true,
            onChanged: null,
            title: Text('Carte éco (habitat du chevreuil)'),
            subtitle: Text('Toujours incluse'),
          ),
          for (final layer in _rasterLayers)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selectedLayerIds.contains(layer.id),
              onChanged: _downloading
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _selectedLayerIds.add(layer.id);
                        } else {
                          _selectedLayerIds.remove(layer.id);
                        }
                      }),
              title: Text(layer.label),
              subtitle: layer.id == 'satellite'
                  ? const Text('Zooms 10 à 14 — repérer champs et clairières')
                  : const Text('Zooms 10 à 14 — relief et sentiers'),
            ),
          const SizedBox(height: 8),
          if (_downloading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ] else if (_done) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(_status)),
              ],
            ),
          ] else
            FilledButton.icon(
              onPressed: () {
                final bounds = _lastBounds ?? _mapController.camera.visibleBounds;
                final size = _mapController.camera.nonRotatedSize;
                final inset = _insetBounds(bounds, size);
                _startDownload(inset);
              },
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Télécharger ce territoire'),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const Text('Territoires téléchargés', style: TextStyle(fontWeight: FontWeight.bold)),
          if (widget.zones.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun territoire téléchargé pour l\'instant.'),
            )
          else
            ...widget.zones.map(
              (zone) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.map_outlined),
                title: Text(zone.nom),
                subtitle: Text(
                  '${_dateLabel(zone.date)} · ${zone.layers.isNotEmpty ? zone.layers.join(', ') : '${zone.tileCountEco} tuiles éco'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => widget.onZoneDeleted(zone),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
