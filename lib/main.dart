import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web : l'initialisation JS de Firebase est instable dans certains
  // environnements (problème de canal pigeon) — le web ne sert qu'aux
  // vérifications visuelles de cette app mobile, donc on ne l'initialise
  // pas du tout plutôt que de risquer de déstabiliser le rendu. iOS/Android
  // utilisent les canaux natifs, non affectés par ce problème.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
  }
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
      home: const SplashScreen(),
    );
  }
}
