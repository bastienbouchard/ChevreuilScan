import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/champ.dart';

const _prefsKey = 'chevreuilscan_champs';

Future<List<Champ>> loadChamps() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return [];
  final list = json.decode(raw) as List;
  return list.map((e) => Champ.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> saveChamps(List<Champ> champs) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = json.encode(champs.map((c) => c.toJson()).toList());
  await prefs.setString(_prefsKey, raw);
}
