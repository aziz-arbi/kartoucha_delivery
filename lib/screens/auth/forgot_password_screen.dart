import 'dart:async'; // for StreamSubscription
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import 'login_screen.dart'; // to navigate back after reset

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _requestSent = false;
  String? _resetDocId;
  StreamSubscription? _resetStream;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resetStream?.cancel();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    // Check if phone exists in users or workers
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .get();
    final workerDoc = await FirebaseFirestore.instance
        .collection('workers')
        .where('phone', isEqualTo: phone)
        .get();

    if (userDoc.docs.isEmpty && workerDoc.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun compte trouvé avec ce numéro.')),
        );
      }
      return;
    }

    // Create reset request
    final docRef = await FirebaseFirestore.instance
        .collection('password_resets')
        .add({
          'phone': phone,
          'requestedAt': FieldValue.serverTimestamp(),
          'approved': false,
          'denied': false,
        });

    setState(() {
      _requestSent = true;
      _resetDocId = docRef.id;
    });

    // Listen for approval/denial
    _resetStream = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      if (data['denied'] == true) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Demande refusée'),
              content: Text(
                data['denialReason'] ?? 'Votre demande a été refusée.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // go back to login
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else if (data['approved'] == true) {
        setState(() {});
      }
    });
  }

  Future<void> _verifyCodeAndReset() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPass.isEmpty || confirm.isEmpty || newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(_resetDocId)
          .get();
      final data = doc.data()!;
      final storedCode = data['verificationCode']?.toString() ?? '';
      if (storedCode != code) {
        throw 'Code incorrect';
      }

      // Store the new password temporarily for admin to apply
      await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(_resetDocId)
          .update({'newPassword': newPass, 'completed': true});

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mot de passe mis à jour'),
            content: const Text(
              'Votre nouveau mot de passe sera appliqué après validation administrative.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(t('forgot_password', lang))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _requestSent
            ? Column(
                children: [
                  if (_resetDocId != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('password_resets')
                          .doc(_resetDocId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data =
                            snapshot.data?.data() as Map<String, dynamic>?;
                        final approved = data?['approved'] == true;
                        return Column(
                          children: [
                            Text(
                              approved
                                  ? 'Code approuvé. Entrez le code et votre nouveau mot de passe.'
                                  : 'Demande envoyée. En attente d\'approbation.',
                            ),
                            if (approved) ...[
                              TextFormField(
                                controller: _codeController,
                                decoration: const InputDecoration(
                                  labelText: 'Code',
                                ),
                              ),
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Nouveau mot de passe',
                                ),
                              ),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Confirmer',
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _verifyCodeAndReset,
                                child: const Text('Valider'),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                ],
              )
            : Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitPhone,
                    child: const Text('Envoyer la demande'),
                  ),
                ],
              ),
      ),
    );
  }
}
