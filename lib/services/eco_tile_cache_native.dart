import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _dir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'eco_tiles'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<Uint8List?> readCachedEcoTile(String tileName) async {
  try {
    final file = File(p.join((await _dir()).path, tileName));
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> writeCachedEcoTile(String tileName, Uint8List bytes) async {
  try {
    final file = File(p.join((await _dir()).path, tileName));
    await file.writeAsBytes(bytes, flush: true);
  } catch (_) {
    // Échec d'écriture disque ignoré : la tuile reste servie depuis le
    // réseau/la mémoire, seule la persistance hors-ligne est perdue.
  }
}

Future<int> ecoTileCacheSizeBytes() async {
  var total = 0;
  final dir = await _dir();
  if (!await dir.exists()) return 0;
  await for (final entity in dir.list()) {
    if (entity is File) total += await entity.length();
  }
  return total;
}

Future<void> clearEcoTileCache() async {
  final dir = await _dir();
  if (await dir.exists()) await dir.delete(recursive: true);
}
