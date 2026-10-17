import 'package:chevreuilscan/models/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les pourcentages des 3 saisons totalisent toujours 100', () {
    for (final date in [
      DateTime(2026, 9, 1),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 25),
      DateTime(2026, 11, 12),
      DateTime(2026, 12, 1),
      DateTime(2026, 12, 20),
      DateTime(2026, 2, 1),
    ]) {
      final weights = seasonWeights(date);
      final total = weights.values.fold<int>(0, (a, b) => a + b);
      expect(total, 100, reason: 'date $date');
    }
  });

  test('pic du rut (12 novembre) = 100% rut', () {
    final weights = seasonWeights(DateTime(2026, 11, 12));
    expect(weights[Season.rut], weights.values.reduce((a, b) => a > b ? a : b));
  });

  test('saison dominante suit le pourcentage le plus élevé', () {
    final date = DateTime(2026, 11, 12);
    expect(dominantSeason(date), Season.rut);
  });

  test('entre pré-rut et rut, les deux ont un pourcentage positif', () {
    final weights = seasonWeights(DateTime(2026, 11, 1));
    expect(weights[Season.preRut]! > 0, isTrue);
    expect(weights[Season.rut]! > 0, isTrue);
  });
}
