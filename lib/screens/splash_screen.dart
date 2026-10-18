import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'map_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Web : Firebase ne s'initialise pas de façon fiable dans tous les
    // environnements (voir main.dart) — le web ne sert qu'aux
    // vérifications visuelles de cette app mobile, donc on saute la
    // connexion obligatoire plutôt que de rester bloqué indéfiniment.
    final next = (kIsWeb || AuthService.isLoggedIn) ? const MapPage() : const LoginPage();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
