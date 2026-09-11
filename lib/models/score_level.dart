import 'package:flutter/material.dart';

enum ScoreLevel { excellent, bon, moyen, faible }

extension ScoreLevelStyle on ScoreLevel {
  String get label => switch (this) {
        ScoreLevel.excellent => 'Excellent',
        ScoreLevel.bon => 'Bon',
        ScoreLevel.moyen => 'Moyen',
        ScoreLevel.faible => 'Faible',
      };

  Color get color => switch (this) {
        ScoreLevel.excellent => const Color(0xFF1B5E20),
        ScoreLevel.bon => const Color(0xFF4CAF50),
        ScoreLevel.moyen => const Color(0xFFFFD600),
        ScoreLevel.faible => const Color(0xFFE53935),
      };
}

ScoreLevel scoreLevelFromRatio(double ratio) {
  if (ratio >= 0.50) return ScoreLevel.excellent;
  if (ratio >= 0.32) return ScoreLevel.bon;
  if (ratio >= 0.16) return ScoreLevel.moyen;
  return ScoreLevel.faible;
}
