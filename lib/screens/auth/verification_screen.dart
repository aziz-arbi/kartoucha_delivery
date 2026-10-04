import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../services/auth_service.dart';
import '../client/client_home.dart';

class VerificationScreen extends StatefulWidget {
  final String phone;
  const VerificationScreen({super.key, required this.phone});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

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
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('verification', lang)),
        backgroundColor: const Color(0xFFFF5724),
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5724), Color(0xFFFF8B3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5724).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: const Icon(
                        Icons.sms,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('verification_sent', lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.phone,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        t('enter_code', lang),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '------',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 24,
                            letterSpacing: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          counterText: '',
                        ),
                        maxLength: 6,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _verifyCode,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            t('verify', lang),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5724),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 4,
                          ),
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
    );
  }

  Future<void> _verifyCode() async {
    final enteredCode = _codeController.text.trim();

    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrez le code')));
      return;
    }

    if (enteredCode.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text('Le code doit contenir 6 chiffres')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rawPhone = widget.phone.trim();
      final normalizedPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

      final phoneVariants = <String>{
        rawPhone,
        normalizedPhone,
        if (normalizedPhone.startsWith('+216'))
          normalizedPhone.substring(4),
        if (normalizedPhone.startsWith('216') && normalizedPhone.length > 8)
          normalizedPhone.substring(3),
      }.where((phone) => phone.isNotEmpty).toList();

      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('pending_users')
          .where('phone', isEqualTo: phoneVariants.first)
          .where('approved', isEqualTo: true)
          .limit(1)
          .get();

      for (final phone in phoneVariants.skip(1)) {
        if (query.docs.isNotEmpty) break;

        query = await FirebaseFirestore.instance
            .collection('pending_users')
            .where('phone', isEqualTo: phone)
            .where('approved', isEqualTo: true)
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty) {
        throw 'Aucun compte approuvé trouvé pour ${widget.phone}. Contactez l\'administrateur.';
      }

      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      if (data['denied'] == true) {
        throw 'Cette demande a été refusée.';
      }

      final storedCode = data['verificationCode']?.toString().trim() ?? '';

      if (storedCode.isEmpty) {
        throw 'Le code de vérification est en cours d\'envoi sur WhatsApp. Réessayez dans quelques secondes.';
      }

      final expiresAt = data['verificationExpiresAt'];
      if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
        throw 'Ce code a expiré. Demandez un nouveau code.';
      }

      if (storedCode != enteredCode) {
        throw 'Code incorrect. Vérifiez le code envoyé par WhatsApp.';
      }

      await AuthService().createApprovedUser(
        doc.id,
        data['name'],
        data['phone'],
        data['password'],
      );

      await doc.reference.delete();

      try {
        final token = await FirebaseMessaging.instance.getToken();
        final currentUser = FirebaseAuth.instance.currentUser;
        if (token != null && currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'fcmToken': token});
        }
      } catch (e) {
        debugPrint('FCM token save failed: $e');
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
          (route) => false,
        );
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
