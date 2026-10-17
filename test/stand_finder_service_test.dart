import 'package:chevreuilscan/models/season.dart';
import 'package:chevreuilscan/services/deer_habitat_service.dart';
import 'package:chevreuilscan/services/stand_finder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

StandCandidate _candidate(double lat, double lon, double ratio, {String zoneLabel = 'zone de test'}) {
  return StandCandidate(centroid: LatLng(lat, lon), ratio: ratio, zoneLabel: zoneLabel);
}

void main() {
  test('poste placé sous le vent (au sud si le vent vient du nord)', () {
    final recs = findBestStands(
      candidates: [_candidate(48.0, -71.0, 0.8)],
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
    final recs = findBestStands(
      candidates: [_candidate(48.0, -71.0, 0.8)],
      windFromDeg: 180, // vent venant du sud
    );

    expect(recs, hasLength(1));
    expect(recs.first.position.latitude, greaterThan(recs.first.targetZone.latitude));
  });

  test('retourne une liste vide si aucune zone avec un ratio positif', () {
    final recs = findBestStands(candidates: [_candidate(48.0, -71.0, 0.0)], windFromDeg: 0);
    expect(recs, isEmpty);
  });

  test('retourne plusieurs choix distincts, classés par ratio', () {
    final recs = findBestStands(
      candidates: [
        _candidate(48.00, -71.00, 0.9), // meilleur
        _candidate(48.02, -71.00, 0.4), // plus faible, assez loin pour être distinct
      ],
      windFromDeg: 0,
      maxResults: 3,
    );

    expect(recs.length, 2);
    expect(recs[0].rank, 1);
    expect(recs[1].rank, 2);
  });

  test('ignore les zones trop proches d\'un choix déjà retenu', () {
    final recs = findBestStands(
      candidates: [
        _candidate(48.000, -71.000, 0.9),
        _candidate(48.0005, -71.000, 0.7), // à ~55m du premier, en-deçà de minSeparationM
      ],
      windFromDeg: 0,
      minSeparationM: 150,
    );

    expect(recs, hasLength(1));
  });

  test('respecte maxResults', () {
    final candidates = [for (var i = 0; i < 5; i++) _candidate(48.0 + i * 0.01, -71.0, 0.5)];
    final recs = findBestStands(candidates: candidates, windFromDeg: 0, maxResults: 2);
    expect(recs, hasLength(2));
  });

  test('un champ agricole peut dominer un peuplement forestier moins bon', () {
    final ecoRatio = scoreDeerHabitat({'type_couv': 'R', 'gr_ess': 'EN'}, Season.preRut).ratio;
    final recs = findBestStands(
      candidates: [
        _candidate(48.00, -71.00, ecoRatio, zoneLabel: seasonZoneLabel(Season.preRut)),
        _candidate(48.02, -71.00, 0.95, zoneLabel: 'champ de maïs'),
      ],
      windFromDeg: 0,
    );
    expect(recs.first.reason, contains('champ de maïs'));
  });
}
