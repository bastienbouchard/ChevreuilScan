class DownloadedZone {
  final String id;
  final String nom;
  final DateTime date;
  final int tileCountEco;
  final int tileCountRaster;
  final List<String> layers;

  const DownloadedZone({
    required this.id,
    required this.nom,
    required this.date,
    required this.tileCountEco,
    required this.tileCountRaster,
    this.layers = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'date': date.toIso8601String(),
        'tileCountEco': tileCountEco,
        'tileCountRaster': tileCountRaster,
        'layers': layers,
      };

  factory DownloadedZone.fromJson(Map<String, dynamic> json) => DownloadedZone(
        id: json['id'] as String,
        nom: json['nom'] as String,
        date: DateTime.parse(json['date'] as String),
        tileCountEco: json['tileCountEco'] as int? ?? 0,
        tileCountRaster: json['tileCountRaster'] as int? ?? 0,
        layers: (json['layers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      );
}
