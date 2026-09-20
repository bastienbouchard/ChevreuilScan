import 'package:latlong2/latlong.dart';

class Track {
  final String id;
  final String nom;
  final DateTime date;
  final List<LatLng> points;

  const Track({
    required this.id,
    required this.nom,
    required this.date,
    required this.points,
  });

  double get distanceM {
    double total = 0;
    for (var i = 0; i < points.length - 1; i++) {
      total += const Distance().as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return total;
  }

  String get distanceLabel {
    final d = distanceM;
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'date': date.toIso8601String(),
        'points': points.map((p) => [p.latitude, p.longitude]).toList(),
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        nom: json['nom'] as String,
        date: DateTime.parse(json['date'] as String),
        points: (json['points'] as List)
            .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList(),
      );
}
