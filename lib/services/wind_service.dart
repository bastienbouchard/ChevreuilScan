import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WindInfo {
  final double deg;
  final double speed;
  final bool cached;

  const WindInfo({required this.deg, required this.speed, required this.cached});
}

const _kWindDeg = 'wind_deg';
const _kWindSpeed = 'wind_speed';

Future<WindInfo?> fetchWind(double latitude, double longitude) async {
  try {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&current=wind_speed_10m,wind_direction_10m',
    );
    final resp = await http.get(url).timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      final deg = (current?['wind_direction_10m'] as num?)?.toDouble();
      final speed = (current?['wind_speed_10m'] as num?)?.toDouble();
      if (deg == null) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kWindDeg, deg);
      await prefs.setDouble(_kWindSpeed, speed ?? 0);
      return WindInfo(deg: deg, speed: speed ?? 0, cached: false);
    }
  } catch (_) {
    // Réseau indisponible — on retombe sur la dernière valeur connue.
  }
  final prefs = await SharedPreferences.getInstance();
  final deg = prefs.getDouble(_kWindDeg);
  final speed = prefs.getDouble(_kWindSpeed);
  if (deg != null) return WindInfo(deg: deg, speed: speed ?? 0, cached: true);
  return null;
}

String windCardinal(double deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
  return dirs[((deg + 22.5) / 45).floor() % 8];
}
