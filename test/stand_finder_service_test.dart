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

    final rec = findBestStand(
      features: features,
      season: Season.preRut,
      windFromDeg: 0, // vent venant du nord
    );

    expect(rec, isNotNull);
    // Le vent vient du nord (souffle vers le sud) → le chasseur doit être
    // au sud de la zone pour que son odeur soit emportée à l'opposé.
    expect(rec!.position.latitude, lessThan(rec.targetZone.latitude));
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

    final rec = findBestStand(
      features: features,
      season: Season.preRut,
      windFromDeg: 180, // vent venant du sud
    );

    expect(rec, isNotNull);
    expect(rec!.position.latitude, greaterThan(rec.targetZone.latitude));
  });

  test('retourne null si aucune zone avec un score positif', () {
    final features = [
      _square(48.0, -71.0, {'type_eco': 'EAU'}),
    ];

    final rec = findBestStand(features: features, season: Season.preRut, windFromDeg: 0);
    expect(rec, isNull);
  });
}
