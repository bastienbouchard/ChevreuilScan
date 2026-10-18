import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'map_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isCreating) {
        await AuthService.createWithEmail(email, pass);
      } else {
        await AuthService.signInWithEmail(email, pass);
      }
      await AuthService.ensureUserDoc();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MapPage()));
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Entre ton email pour réinitialiser le mot de passe');
      return;
    }
    await AuthService.resetPassword(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de réinitialisation envoyé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 64),
                const SizedBox(height: 12),
                const Text(
                  'Chevreuil SCAN',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCreating ? 'Créer un compte' : 'Connexion',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 32),
                _field(_emailCtrl, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_passCtrl, 'Mot de passe', Icons.lock_outline, obscure: true),
                const SizedBox(height: 8),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 12),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isCreating ? 'Créer le compte' : 'Se connecter',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() {
                    _isCreating = !_isCreating;
                    _error = null;
                  }),
                  child: Text(
                    _isCreating ? 'Déjà un compte? Se connecter' : 'Pas de compte? Créer un compte',
                    style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 13),
                  ),
                ),
                if (!_isCreating)
                  TextButton(
                    onPressed: _resetPassword,
                    child: Text('Mot de passe oublié?', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}
