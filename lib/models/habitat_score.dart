import 'score_level.dart';

class HabitatScore {
  final int value;
  final int maxValue;
  final ScoreLevel level;
  final List<String> reasons;

  const HabitatScore({
    required this.value,
    required this.maxValue,
    required this.level,
    required this.reasons,
  });

  double get ratio => maxValue == 0 ? 0 : (value / maxValue).clamp(0.0, 1.0);

  factory HabitatScore.fromRaw(int value, int maxValue, List<String> reasons) {
    final ratio = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return HabitatScore(
      value: value,
      maxValue: maxValue,
      level: scoreLevelFromRatio(ratio),
      reasons: reasons,
    );
  }
}
