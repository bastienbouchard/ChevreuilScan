import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import 'auth_service.dart';

const _prefsKey = 'chevreuilscan_tracks';

Future<List<Track>> loadTracks() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw != null) {
    final list = json.decode(raw) as List;
    return list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
  }
  // Rien en local (ex. nouvel appareil) : on tente de restaurer depuis le
  // compte, sinon on repart d'une liste vide.
  final uid = AuthService.uid;
  if (uid == null) return [];
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final remote = (doc.data()?['tracks'] as List?) ?? [];
    final tracks = remote.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    if (tracks.isNotEmpty) await saveTracks(tracks);
    return tracks;
  } catch (_) {
    return [];
  }
}

Future<void> saveTracks(List<Track> tracks) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = tracks.map((t) => t.toJson()).toList();
  await prefs.setString(_prefsKey, json.encode(jsonList));

  final uid = AuthService.uid;
  if (uid == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'tracks': jsonList}, SetOptions(merge: true));
  } catch (_) {
    // Pas de réseau : la sauvegarde locale suffit, on resynchronisera
    // au prochain saveTracks réussi.
  }
}
