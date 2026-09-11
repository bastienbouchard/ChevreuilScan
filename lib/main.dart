import 'package:flutter/material.dart';

import 'screens/map_page.dart';

void main() {
  runApp(const ChevreuilScanApp());
}

class ChevreuilScanApp extends StatelessWidget {
  const ChevreuilScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChevreuilScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}
