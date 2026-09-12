import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/observation.dart';

const _prefsKey = 'chevreuilscan_observations';

Future<List<Observation>> loadObservations() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return [];
  final list = json.decode(raw) as List;
  return list.map((e) => Observation.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> saveObservations(List<Observation> observations) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = json.encode(observations.map((o) => o.toJson()).toList());
  await prefs.setString(_prefsKey, raw);
}
