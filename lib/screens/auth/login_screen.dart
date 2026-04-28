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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ----- Header with gradient -----
              Container(
                height: 260,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF5724), Color(0xFFFF8B3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF5724),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Language switcher at top right
                      Align(
                        alignment: Alignment.topRight,
                        child: PopupMenuButton<String>(
                          onSelected: (value) async {
                            await languageProvider.setLanguage(value);
                            setState(() {});
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'fr',
                              child: Text('Français'),
                            ),
                            const PopupMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            const PopupMenuItem(
                              value: 'ar',
                              child: Text('Tounsi'),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16, top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getLanguageDisplay(lang),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Logo and title
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('title', lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ----- Form card -----
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Card(
                    elevation: 8,
                    shadowColor: const Color(0xFFFF5724).withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Biometric icon
                            InkWell(
                              onTap: _tryBiometricLogin,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFFFF5724,
                                  ).withOpacity(0.1),
                                ),
                                child: const Icon(
                                  Icons.fingerprint,
                                  size: 40,
                                  color: Color(0xFFFF5724),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t('biometric_hint', lang),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: t('phone', lang),
                                prefixIcon: const Icon(
                                  Icons.phone,
                                  color: Color(0xFFFF5724),
                                ),
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
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xFFFF8B3D),
                                ),
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
                                    SnackBar(
                                      content: Text(t('contact_admin', lang)),
                                    ),
                                  );
                                },
                                child: Text(t('forgot', lang)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5724),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        t('login', lang),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: "${t('no_account', lang)} ",
                                  style: TextStyle(color: Colors.grey.shade600),
                                  children: [
                                    TextSpan(
                                      text: t('signup', lang),
                                      style: const TextStyle(
                                        color: Color(0xFFFF5724),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedPhone', _phoneController.text.trim());
        await prefs.setString('savedPassword', _passwordController.text);
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
