import 'package:latlong2/latlong.dart';

enum CropType { mais, foin, cereales, trefle, luzerne, jachere }

extension CropTypeLabel on CropType {
  String get label => switch (this) {
        CropType.mais => 'Maïs',
        CropType.foin => 'Foin',
        CropType.cereales => 'Céréales',
        CropType.trefle => 'Trèfle',
        CropType.luzerne => 'Luzerne',
        CropType.jachere => 'Jachère',
      };
}

class Champ {
  final String id;
  final List<LatLng> polygon;
  final CropType crop;
  final DateTime harvestDate;
  final double hauteurCm;
  final bool hasBordures;

  const Champ({
    required this.id,
    required this.polygon,
    required this.crop,
    required this.harvestDate,
    required this.hauteurCm,
    required this.hasBordures,
  });
}
