import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';

const _prefsKey = 'chevreuilscan_tracks';

Future<List<Track>> loadTracks() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return [];
  final list = json.decode(raw) as List;
  return list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> saveTracks(List<Track> tracks) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = json.encode(tracks.map((t) => t.toJson()).toList());
  await prefs.setString(_prefsKey, raw);
}
