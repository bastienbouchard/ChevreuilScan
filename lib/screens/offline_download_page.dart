import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/downloaded_zone.dart';
import '../services/eco_tile_service.dart';
import '../services/tile_cache_service.dart';

const _ecoMaxTiles = 12;
const _rasterMaxTiles = 4000;
const _rasterMinZoom = 10;
const _rasterMaxZoom = 14;
const _insetMargin = 28.0;

class OfflineDownloadPage extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final String baseLayerLabel;
  final String baseUrlTemplate;
  final EcoTileService tileService;
  final List<DownloadedZone> zones;
  final ValueChanged<DownloadedZone> onZoneDownloaded;
  final ValueChanged<DownloadedZone> onZoneDeleted;

  const OfflineDownloadPage({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    required this.baseLayerLabel,
    required this.baseUrlTemplate,
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
  bool _includeRaster = true;
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
    int rasterCount = 0;
    if (_includeRaster) {
      rasterCount = TileCacheService.instance.estimateTileCount(
        south: insetBounds.south,
        west: insetBounds.west,
        north: insetBounds.north,
        east: insetBounds.east,
        minZoom: _rasterMinZoom,
        maxZoom: _rasterMaxZoom,
      );
      if (rasterCount > _rasterMaxTiles) {
        _showSnack('Zone trop grande pour le fond de carte — zoome davantage.');
        return;
      }
    }

    final nom = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Nom de la zone'),
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

    if (_includeRaster) {
      await TileCacheService.instance.downloadTiles(
        urlTemplate: widget.baseUrlTemplate,
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
            _status = 'Fond de carte : tuile $done/$total';
          });
        },
      );
    }

    final zone = DownloadedZone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nom: nom,
      date: DateTime.now(),
      tileCountEco: ecoTiles.length,
      tileCountRaster: _includeRaster ? rasterCount : 0,
    );
    widget.onZoneDownloaded(zone);

    if (!mounted) return;
    setState(() {
      _downloading = false;
      _done = true;
      _status = 'Zone "$nom" téléchargée et disponible hors ligne.';
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
      appBar: AppBar(title: const Text('Télécharger une zone')),
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
                          TileLayer(urlTemplate: widget.baseUrlTemplate, userAgentPackageName: 'com.bastienbouchard.chevreuilscan'),
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeRaster,
            onChanged: _downloading ? null : (v) => setState(() => _includeRaster = v ?? true),
            title: Text('Inclure le fond de carte (${widget.baseLayerLabel})'),
            subtitle: const Text('Zooms 10 à 14 — suffisant pour se repérer sur le terrain'),
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
              label: const Text('Télécharger cette zone'),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const Text('Zones téléchargées', style: TextStyle(fontWeight: FontWeight.bold)),
          if (widget.zones.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucune zone téléchargée pour l\'instant.'),
            )
          else
            ...widget.zones.map(
              (zone) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.map_outlined),
                title: Text(zone.nom),
                subtitle: Text(
                  '${_dateLabel(zone.date)} · ${zone.tileCountEco} tuiles éco'
                  '${zone.tileCountRaster > 0 ? ' · ${zone.tileCountRaster} tuiles carte' : ''}',
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
