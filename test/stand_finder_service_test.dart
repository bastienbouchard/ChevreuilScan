import 'package:chevreuilscan/models/season.dart';
import 'package:chevreuilscan/services/eco_feature_parser.dart';
import 'package:chevreuilscan/services/stand_finder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

EcoFeature _square(double lat, double lon, Map<String, dynamic> props) {
  const d = 0.001;
  return EcoFeature(props: props, rings: [
    [
      LatLng(lat - d, lon - d),
      LatLng(lat - d, lon + d),
      LatLng(lat + d, lon + d),
      LatLng(lat + d, lon - d),
    ],
  ]);
}

void main() {
  test('poste placé sous le vent (au sud si le vent vient du nord)', () {
    final features = [
      _square(48.0, -71.0, {
        'type_couv': 'F',
        'gr_ess': 'PE',
        'origine': 'CP',
        'cl_age': '10',
      }),
    ];

    final recs = findBestStands(
      features: features,
      season: Season.preRut,
      windFromDeg: 0, // vent venant du nord
    );

    expect(recs, hasLength(1));
    final rec = recs.first;
    expect(rec.rank, 1);
    // Le vent vient du nord (souffle vers le sud) → le chasseur doit être
    // au sud de la zone pour que son odeur soit emportée à l'opposé.
    expect(rec.position.latitude, lessThan(rec.targetZone.latitude));
    expect(rec.position.longitude, closeTo(rec.targetZone.longitude, 0.0005));
  });

  test('poste placé au nord si le vent vient du sud', () {
    final features = [
      _square(48.0, -71.0, {
        'type_couv': 'F',
        'gr_ess': 'PE',
        'origine': 'CP',
        'cl_age': '10',
      }),
    ];

    final recs = findBestStands(
      features: features,
      season: Season.preRut,
      windFromDeg: 180, // vent venant du sud
    );

    expect(recs, hasLength(1));
    expect(recs.first.position.latitude, greaterThan(recs.first.targetZone.latitude));
  });

  test('retourne une liste vide si aucune zone avec un score positif', () {
    final features = [
      _square(48.0, -71.0, {'type_eco': 'EAU'}),
    ];

    final recs = findBestStands(features: features, season: Season.preRut, windFromDeg: 0);
    expect(recs, isEmpty);
  });

  test('retourne plusieurs choix distincts, classés par score', () {
    final features = [
      _square(48.00, -71.00, {
        'type_couv': 'F',
        'gr_ess': 'PE',
        'origine': 'CP',
        'cl_age': '10',
        'cl_drai': '3',
        'cl_dens': 'B',
      }), // meilleur score
      _square(48.02, -71.00, {
        'type_couv': 'F',
        'gr_ess': 'PE',
      }), // score plus faible, assez loin pour être distinct
    ];

    final recs = findBestStands(features: features, season: Season.preRut, windFromDeg: 0, maxResults: 3);

    expect(recs.length, 2);
    expect(recs[0].rank, 1);
    expect(recs[1].rank, 2);
  });

  test('ignore les zones trop proches d\'un choix déjà retenu', () {
    final features = [
      _square(48.000, -71.000, {
        'type_couv': 'F',
        'gr_ess': 'PE',
        'origine': 'CP',
        'cl_age': '10',
        'cl_drai': '3',
        'cl_dens': 'B',
      }),
      _square(48.0005, -71.000, {
        'type_couv': 'F',
        'gr_ess': 'PE',
        'origine': 'CP',
        'cl_age': '10',
        'cl_drai': '3',
        'cl_dens': 'B',
      }), // à ~55m du premier, en-deçà de minSeparationM
    ];

    final recs = findBestStands(
      features: features,
      season: Season.preRut,
      windFromDeg: 0,
      minSeparationM: 150,
    );

    expect(recs, hasLength(1));
  });

  test('respecte maxResults', () {
    final features = [
      for (var i = 0; i < 5; i++)
        _square(48.0 + i * 0.01, -71.0, {
          'type_couv': 'F',
          'gr_ess': 'PE',
          'origine': 'CP',
          'cl_age': '10',
        }),
    ];

    final recs = findBestStands(features: features, season: Season.preRut, windFromDeg: 0, maxResults: 2);
    expect(recs, hasLength(2));
  });
}
