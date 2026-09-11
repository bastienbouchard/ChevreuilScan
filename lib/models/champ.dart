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

  Map<String, dynamic> toJson() => {
        'id': id,
        'polygon': polygon.map((p) => [p.latitude, p.longitude]).toList(),
        'crop': crop.name,
        'harvestDate': harvestDate.toIso8601String(),
        'hauteurCm': hauteurCm,
        'hasBordures': hasBordures,
      };

  factory Champ.fromJson(Map<String, dynamic> json) {
    return Champ(
      id: json['id'] as String,
      polygon: (json['polygon'] as List)
          .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(),
      crop: CropType.values.firstWhere((c) => c.name == json['crop']),
      harvestDate: DateTime.parse(json['harvestDate'] as String),
      hauteurCm: (json['hauteurCm'] as num).toDouble(),
      hasBordures: json['hasBordures'] as bool,
    );
  }
}
