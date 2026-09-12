import 'package:latlong2/latlong.dart';

enum ObservationType {
  chevreuil,
  crottins,
  traces,
  broutage,
  frottage,
  grattage,
  couchage,
  sentier,
  nourriture,
  poste,
  bonVent,
  camera,
  saline,
  cache,
}

extension ObservationTypeStyle on ObservationType {
  String get emoji => switch (this) {
        ObservationType.chevreuil => '🦌',
        ObservationType.crottins => '💩',
        ObservationType.traces => '👣',
        ObservationType.broutage => '🌿',
        ObservationType.frottage => '🌳',
        ObservationType.grattage => '🟤',
        ObservationType.couchage => '🛏️',
        ObservationType.sentier => '🚶',
        ObservationType.nourriture => '🌾',
        ObservationType.poste => '🎯',
        ObservationType.bonVent => '💨',
        ObservationType.camera => '📷',
        ObservationType.saline => '🧂',
        ObservationType.cache => '🌲',
      };

  String get label => switch (this) {
        ObservationType.chevreuil => 'Chevreuil',
        ObservationType.crottins => 'Crottins',
        ObservationType.traces => 'Traces',
        ObservationType.broutage => 'Broutage',
        ObservationType.frottage => 'Frottage',
        ObservationType.grattage => 'Grattage',
        ObservationType.couchage => 'Couchage',
        ObservationType.sentier => 'Sentier',
        ObservationType.nourriture => 'Nourriture',
        ObservationType.poste => 'Poste',
        ObservationType.bonVent => 'Bon vent',
        ObservationType.camera => 'Caméra',
        ObservationType.saline => 'Saline',
        ObservationType.cache => 'Cache',
      };
}

class Observation {
  final String id;
  final LatLng position;
  final ObservationType type;
  final DateTime timestamp;

  const Observation({
    required this.id,
    required this.position,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': position.latitude,
        'lon': position.longitude,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Observation.fromJson(Map<String, dynamic> json) => Observation(
        id: json['id'] as String,
        position: LatLng((json['lat'] as num).toDouble(), (json['lon'] as num).toDouble()),
        type: ObservationType.values.firstWhere((t) => t.name == json['type']),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
