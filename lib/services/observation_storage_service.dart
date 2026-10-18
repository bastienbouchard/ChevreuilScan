import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/observation.dart';
import 'auth_service.dart';

const _prefsKey = 'chevreuilscan_observations';

Future<List<Observation>> loadObservations() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw != null) {
    final list = json.decode(raw) as List;
    return list.map((e) => Observation.fromJson(e as Map<String, dynamic>)).toList();
  }
  final uid = AuthService.uid;
  if (uid == null) return [];
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final remote = (doc.data()?['observations'] as List?) ?? [];
    final observations =
        remote.map((e) => Observation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    if (observations.isNotEmpty) await saveObservations(observations);
    return observations;
  } catch (_) {
    return [];
  }
}

Future<void> saveObservations(List<Observation> observations) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = observations.map((o) => o.toJson()).toList();
  await prefs.setString(_prefsKey, json.encode(jsonList));

  final uid = AuthService.uid;
  if (uid == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'observations': jsonList}, SetOptions(merge: true));
  } catch (_) {
    // Pas de réseau : la sauvegarde locale suffit.
  }
}
