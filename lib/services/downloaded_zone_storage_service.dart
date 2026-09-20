import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/downloaded_zone.dart';

const _prefsKey = 'chevreuilscan_downloaded_zones';

Future<List<DownloadedZone>> loadDownloadedZones() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return [];
  final list = json.decode(raw) as List;
  return list.map((e) => DownloadedZone.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> saveDownloadedZones(List<DownloadedZone> zones) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = json.encode(zones.map((z) => z.toJson()).toList());
  await prefs.setString(_prefsKey, raw);
}
