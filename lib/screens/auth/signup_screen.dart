import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../utils/phone_validator.dart';
import '../../services/auth_service.dart';
import 'verification_screen.dart';
import 'package:flutter/gestures.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptedTerms = true;   // pre‑checked
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  // URLs for the legal pages – replace with your actual URLs if different
  static const String privacyUrl =
      'https://aziz-arbi.github.io/3jaja_delivery_legal_pages/privacy_policy.html';
  static const String termsUrl =
      'https://aziz-arbi.github.io/3jaja_delivery_legal_pages/terms_of_service.html';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ---- open a URL in the external browser ----
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('signup', lang)),
        backgroundColor: const Color(0xFFFF8B3D), // Neon Carrot
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header card
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8B3D), Color(0xFFFFB84D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8B3D).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: const Icon(Icons.person_add, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('create_account', lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: t('full_name', lang),
                            prefixIcon: const Icon(Icons.person, color: Color(0xFFFF5724)),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? t('required_field', lang) : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: t('phone', lang),
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF5724)),
                          ),
                          validator: (v) =>
                              PhoneValidator.validate(v, t('required_field', lang)),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: t('password', lang),
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFFFF8B3D)),
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return t('required_field', lang);
                            if (v.length < 6) return t('password_length', lang);
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: t('confirm_password', lang),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFFB84D)),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return t('password_mismatch', lang);
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // -------------------- Terms & Privacy checkbox --------------------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (val) => setState(() => _acceptedTerms = val ?? true),
                              activeColor: const Color(0xFFFF5724),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    children: [
                                      TextSpan(text: '${t('i_accept', lang)} '),
                                      TextSpan(
                                        text: t('terms_of_service', lang),
                                        style: const TextStyle(
                                          color: Color(0xFFFF5724),
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()..onTap = () => _openUrl(termsUrl),
                                      ),
                                      TextSpan(text: ' ${t('and', lang)} '),
                                      TextSpan(
                                        text: t('privacy_policy', lang),
                                        style: const TextStyle(
                                          color: Color(0xFFFF5724),
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()..onTap = () => _openUrl(privacyUrl),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Custom validator message for terms
                        if (!_acceptedTerms)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              t('must_accept_terms', lang),
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // -------------------- End Terms checkbox --------------------

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleSignup,
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              t('signup_button', lang),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8B3D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      // Show a snackbar if terms not accepted (additional to the inline message)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('must_accept_terms', Provider.of<LanguageProvider>(context, listen: false).locale.languageCode))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().registerUser(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(phone: _phoneController.text.trim()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('error', Provider.of<LanguageProvider>(context, listen: false).locale.languageCode)}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}