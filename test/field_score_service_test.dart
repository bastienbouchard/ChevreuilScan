import 'package:chevreuilscan/models/champ.dart';
import 'package:chevreuilscan/models/score_level.dart';
import 'package:chevreuilscan/models/season.dart';
import 'package:chevreuilscan/services/field_score_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 15);

  test('maïs récolté récemment avec bordures = excellent en post-rut', () {
    final champ = Champ(
      id: '1',
      polygon: const [],
      crop: CropType.mais,
      harvestDate: DateTime(2026, 11, 1),
      hauteurCm: 5,
      hasBordures: true,
    );

    final result = scoreField(champ, Season.postRut, now);
    expect(result.level, ScoreLevel.excellent);
  });

  test('maïs sur pied sans bordures = faible', () {
    final champ = Champ(
      id: '2',
      polygon: const [],
      crop: CropType.mais,
      harvestDate: DateTime(2026, 12, 1),
      hauteurCm: 200,
      hasBordures: false,
    );

    final result = scoreField(champ, Season.postRut, now);
    expect(result.level, ScoreLevel.faible);
  });

  test('trèfle bas avec bordures = bon ou excellent en pré-rut', () {
    final champ = Champ(
      id: '3',
      polygon: const [],
      crop: CropType.trefle,
      harvestDate: DateTime(2026, 6, 1),
      hauteurCm: 15,
      hasBordures: true,
    );

    final result = scoreField(champ, Season.preRut, now);
    expect(result.level, anyOf(ScoreLevel.bon, ScoreLevel.excellent));
  });
}
