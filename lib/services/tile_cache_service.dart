import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Cache SQLite des tuiles de fond de carte (OSM/satellite/topo), clé = URL
// complète de la tuile. Même principe que satellite_cache_service.dart
// d'EcoMap : pas de TTL/éviction, un cache-first strict, réseau seulement
// si absent du cache et en ligne.
class TileCacheService {
  TileCacheService._();
  static final TileCacheService instance = TileCacheService._();

  static bool isOnline = true;

  Database? _db;
  final _semaphore = _Semaphore(6);

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'cs_tiles.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE tiles(url TEXT PRIMARY KEY, data BLOB, ts INTEGER)',
      ),
    );
    return _db!;
  }

  Future<Uint8List?> getTile(String url) async {
    if (kIsWeb) return null;
    final db = await _database;
    final rows = await db.query('tiles', where: 'url = ?', whereArgs: [url]);
    if (rows.isEmpty) return null;
    return rows.first['data'] as Uint8List;
  }

  Future<void> putTile(String url, Uint8List data) async {
    if (kIsWeb) return;
    final db = await _database;
    await db.insert(
      'tiles',
      {'url': url, 'data': data, 'ts': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearCache() async {
    if (kIsWeb) return;
    final db = await _database;
    await db.delete('tiles');
  }

  Future<int> cacheSizeBytes() async {
    if (kIsWeb) return 0;
    final db = await _database;
    final rows = await db.rawQuery('SELECT SUM(LENGTH(data)) AS s FROM tiles');
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<Uint8List> fetchAndCache(String url, {Duration timeout = const Duration(seconds: 6)}) async {
    final cached = await getTile(url);
    if (cached != null) return cached;
    if (!isOnline) {
      throw Exception('Hors ligne, tuile non disponible: $url');
    }
    return _semaphore.run(() async {
      final again = await getTile(url);
      if (again != null) return again;
      final resp = await http.get(Uri.parse(url)).timeout(timeout);
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        throw Exception('Échec tuile: $url (${resp.statusCode})');
      }
      unawaited(putTile(url, resp.bodyBytes));
      return resp.bodyBytes;
    });
  }

  /// Télécharge en lot une plage de tuiles XYZ pour une zone donnée
  /// (pré-chargement hors-ligne). Séquentiel, comme EcoMap, pour ne pas
  /// surcharger les serveurs de tuiles.
  Future<void> downloadTiles({
    required String urlTemplate,
    required double south,
    required double west,
    required double north,
    required double east,
    required int minZoom,
    required int maxZoom,
    required void Function(int done, int total) onProgress,
  }) async {
    final urls = <String>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final xMin = _lonToX(west, z);
      final xMax = _lonToX(east, z);
      final yMin = _latToY(north, z);
      final yMax = _latToY(south, z);
      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          urls.add(urlTemplate
              .replaceAll('{z}', '$z')
              .replaceAll('{x}', '$x')
              .replaceAll('{y}', '$y'));
        }
      }
    }
    var done = 0;
    onProgress(0, urls.length);
    for (final url in urls) {
      final existing = await getTile(url);
      if (existing == null) {
        try {
          final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            await putTile(url, resp.bodyBytes);
          }
        } catch (_) {
          // Tuile ignorée, on continue le téléchargement du reste de la zone.
        }
      }
      done++;
      onProgress(done, urls.length);
    }
  }

  int estimateTileCount({
    required double south,
    required double west,
    required double north,
    required double east,
    required int minZoom,
    required int maxZoom,
  }) {
    var total = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final xMin = _lonToX(west, z);
      final xMax = _lonToX(east, z);
      final yMin = _latToY(north, z);
      final yMax = _latToY(south, z);
      total += (xMax - xMin + 1) * (yMax - yMin + 1);
    }
    return total;
  }

  int _lonToX(double lon, int z) => ((lon + 180.0) / 360.0 * (1 << z)).floor();

  int _latToY(double lat, int z) {
    final latRad = lat * math.pi / 180.0;
    final y = (1.0 -
            math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2.0 *
        (1 << z);
    return y.floor();
  }
}

class CachedNetworkTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _CachedTileImage(url);
  }
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  final String url;
  const _CachedTileImage(this.url);

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachedTileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(_CachedTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    try {
      final bytes = await TileCacheService.instance.fetchAndCache(url);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (_) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(_transparentPng);
      return decode(buffer);
    }
  }

  @override
  bool operator ==(Object other) => other is _CachedTileImage && other.url == url;
  @override
  int get hashCode => url.hashCode;
}

final _transparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _Semaphore {
  final int max;
  int _current = 0;
  final _queue = <Completer<void>>[];
  _Semaphore(this.max);

  Future<T> run<T>(Future<T> Function() task) async {
    if (_current >= max) {
      final c = Completer<void>();
      _queue.add(c);
      await c.future;
    }
    _current++;
    try {
      return await task();
    } finally {
      _current--;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}
