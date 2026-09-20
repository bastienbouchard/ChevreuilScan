import 'dart:typed_data';

// Le web ne sert qu'aux vérifications visuelles ponctuelles de cette app
// mobile — pas de persistance disque hors-ligne nécessaire, seulement le
// cache mémoire déjà présent dans EcoTileService.
Future<Uint8List?> readCachedEcoTile(String tileName) async => null;

Future<void> writeCachedEcoTile(String tileName, Uint8List bytes) async {}

Future<int> ecoTileCacheSizeBytes() async => 0;

Future<void> clearEcoTileCache() async {}
