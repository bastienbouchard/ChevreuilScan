enum Season { preRut, rut, postRut }

extension SeasonLabel on Season {
  String get label => switch (this) {
        Season.preRut => 'Pré-rut',
        Season.rut => 'Rut',
        Season.postRut => 'Post-rut',
      };

  // Comportement du chevreuil pendant cette période (pas l'habitat — voir
  // scoreDeerHabitat pour la logique d'habitat elle-même).
  String get description => switch (this) {
        Season.preRut =>
          'Les mâles frottent leur bois et grattent le sol pour marquer '
              'leur territoire; les groupes de femelles commencent à se disperser.',
        Season.rut =>
          'Les mâles cherchent activement les femelles, se déplacent '
              'davantage le jour et sont moins prudents.',
        Season.postRut =>
          'Les mâles sont épuisés et se concentrent sur la nourriture et '
              'le repos; le cheptel retourne à des routines prévisibles.',
      };
}

// Dates-pivots approximatives du rut du cerf de Virginie au Québec — pas de
// calendrier officiel par zone, ajustable si l'observation de terrain diffère.
final _preRutPeak = (10, 20);
final _preRutHalfWidth = 25;
final _rutPeak = (11, 12);
final _rutHalfWidth = 15;
final _postRutPeak = (12, 10);
final _postRutHalfWidth = 25;

double _triangleWeight(DateTime date, (int, int) peakMonthDay, int halfWidthDays) {
  final peak = DateTime(date.year, peakMonthDay.$1, peakMonthDay.$2);
  final days = date.difference(peak).inDays.abs();
  final w = 1 - days / halfWidthDays;
  return w > 0 ? w : 0;
}

/// Pourcentage de chaque saison selon la date donnée (ex. 55% pré-rut,
/// 45% rut, 0% post-rut à la mi-fin octobre), pour mettre en évidence où on
/// se situe dans le cycle du rut sans forcer un choix unique.
Map<Season, int> seasonWeights(DateTime date) {
  final raw = {
    Season.preRut: _triangleWeight(date, _preRutPeak, _preRutHalfWidth),
    Season.rut: _triangleWeight(date, _rutPeak, _rutHalfWidth),
    Season.postRut: _triangleWeight(date, _postRutPeak, _postRutHalfWidth),
  };
  final total = raw.values.fold<double>(0, (a, b) => a + b);
  if (total <= 0) {
    // Hors saison (ex. été) : la saison dont le pic est le plus proche
    // reçoit 100 %, pour quand même suggérer un point de départ raisonnable.
    final closest = Season.values.reduce((a, b) =>
        _triangleWeight(date, _peakFor(a), 1000) >= _triangleWeight(date, _peakFor(b), 1000)
            ? a
            : b);
    return {for (final s in Season.values) s: s == closest ? 100 : 0};
  }

  final percents = {for (final e in raw.entries) e.key: e.value / total * 100};
  final rounded = {for (final e in percents.entries) e.key: e.value.round()};
  final drift = 100 - rounded.values.fold<int>(0, (a, b) => a + b);
  if (drift != 0) {
    final dominant = percents.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    rounded[dominant] = (rounded[dominant] ?? 0) + drift;
  }
  return rounded;
}

(int, int) _peakFor(Season season) => switch (season) {
      Season.preRut => _preRutPeak,
      Season.rut => _rutPeak,
      Season.postRut => _postRutPeak,
    };

/// Saison dominante à la date donnée, pour présélectionner intelligemment.
Season dominantSeason(DateTime date) {
  final weights = seasonWeights(date);
  return weights.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}
