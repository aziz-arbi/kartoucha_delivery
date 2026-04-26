import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import '../client/client_home.dart';
import '../worker/worker_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Try biometric login
  Future<void> _tryBiometricLogin() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) return;

    final isAvailable = await _localAuth.isDeviceSupported();
    if (!isAvailable) return;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour continuer.',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (authenticated && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('savedPhone');
        final password = prefs.getString('savedPassword');
        if (phone != null && password != null) {
          _phoneController.text = phone;
          _passwordController.text = password;
          await _handleLogin();
        }
      }
    } catch (e) {
      debugPrint('Erreur biométrique: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('app_name', lang)),
        actions: [
          // Language switcher (existing)
          PopupMenuButton<String>(
            onSelected: (value) async {
              await languageProvider.setLanguage(value);
              setState(() {});
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'fr', child: Text('Français')),
              const PopupMenuItem(value: 'en', child: Text('English')),
              const PopupMenuItem(value: 'ar', child: Text('Tounsi')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(_getLanguageDisplay(lang)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  t('app_name', lang),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                // Biometric login button
                Container(
                  alignment: Alignment.center,
                  child: IconButton(
                    iconSize: 48,
                    icon: Icon(Icons.fingerprint, color: Colors.red.shade400),
                    onPressed: _tryBiometricLogin,
                    tooltip: t('biometric_login', lang),
                  ),
                ),
                const SizedBox(height: 8),
                Text(t('biometric_hint', lang)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: t('phone', lang),
                    prefixIcon: const Icon(Icons.phone),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? t('required_field', lang) : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t('password', lang),
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? t('required_field', lang) : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('contact_admin', lang))),
                      );
                    },
                    child: Text(t('forgot_password', lang)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            t('login', lang),
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  child: Text(
                    t('signup', lang),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLanguageDisplay(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'ar':
        return 'Tounsi';
      default:
        return 'Français';
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      User? user = await auth.signInWithPhoneAndPassword(
        _phoneController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        // Save credentials for future biometric login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedPhone', _phoneController.text.trim());
        await prefs.setString('savedPassword', _passwordController.text);
        // Navigation is handled by AuthWrapper
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
