import 'package:chevreuilscan/models/score_level.dart';
import 'package:chevreuilscan/models/season.dart';
import 'package:chevreuilscan/services/deer_habitat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreDeerHabitat — pré-rut', () {
    test('coupe feuillue récente avec tremble = excellent', () {
      final result = scoreDeerHabitat({
        'type_couv': 'F',
        'gr_ess': 'PE',
        'origine': 'CP',
        'cl_age': '10',
        'cl_drai': '3',
        'cl_dens': 'B',
      }, Season.preRut);

      expect(result.level, ScoreLevel.excellent);
      expect(result.reasons, isNotEmpty);
    });

    test('résineux mature dense = faible en pré-rut', () {
      final result = scoreDeerHabitat({
        'type_couv': 'R',
        'gr_ess': 'EN',
        'origine': 'BS',
        'cl_age': '70',
        'cl_dens': 'D',
      }, Season.preRut);

      expect(result.level, ScoreLevel.faible);
    });
  });

  group('scoreDeerHabitat — rut', () {
    test('peuplement mixte en pente douce avec écotone voisin = excellent', () {
      final result = scoreDeerHabitat(
        {
          'type_couv': 'M',
          'gr_ess': 'BP',
          'cl_age': '20',
          'cl_dens': 'C',
          'cl_pent': 'A',
        },
        Season.rut,
        neighborProps: [
          {'type_couv': 'R'},
          {'type_couv': 'F'},
        ],
      );

      expect(result.level, ScoreLevel.excellent);
      expect(result.reasons.any((r) => r.contains('Écotone')), isTrue);
    });
  });

  group('scoreDeerHabitat — post-rut', () {
    test('cèdre dense = excellent refuge hivernal', () {
      final result = scoreDeerHabitat({
        'type_couv': 'R',
        'gr_ess': 'TO',
        'cl_dens': 'D',
        'cl_drai': '3',
      }, Season.postRut);

      expect(result.level, ScoreLevel.excellent);
    });

    test('feuillu jeune sans conifère = faible en post-rut', () {
      final result = scoreDeerHabitat({
        'type_couv': 'F',
        'gr_ess': 'BJ',
        'cl_age': '10',
        'cl_dens': 'A',
      }, Season.postRut);

      expect(result.level, ScoreLevel.faible);
    });
  });

  test('eau ou milieu urbain retourne toujours faible', () {
    final result = scoreDeerHabitat({'type_eco': 'EAU'}, Season.rut);
    expect(result.level, ScoreLevel.faible);
    expect(result.value, 0);
  });
}
