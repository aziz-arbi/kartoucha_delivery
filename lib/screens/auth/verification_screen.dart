import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/auth_service.dart';
import '../client/client_home.dart';

class VerificationScreen extends StatefulWidget {
  final String phone;
  const VerificationScreen({super.key, required this.phone});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _pendingDocId;
  Stream<QuerySnapshot>? _approvalStream;

  @override
  void initState() {
    super.initState();
    _setupApprovalListener();
  }

  void _setupApprovalListener() {
    _approvalStream = FirebaseFirestore.instance
        .collection('pending_users')
        .where('phone', isEqualTo: widget.phone)
        .snapshots();

    _approvalStream!.listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>?; // Cast to Map

      if (data == null) return;

      // Check for denial first
      if (data['denied'] == true) {
        final reason = data['denialReason'] ?? 'Votre demande a été refusée.';
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Compte refusé'),
              content: Text(reason),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    doc.reference.delete();
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Check for approval
      if (data['approved'] == true) {
        setState(() {
          _pendingDocId = doc.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.message, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Un code de vérification vous sera envoyé via WhatsApp après validation par l\'administrateur.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Code de vérification',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Vérifier', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyCode() async {
    final enteredCode = _codeController.text.trim();
    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez le code')),
      );
      return;
    }

    if (_pendingDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre compte n\'a pas encore été approuvé.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(_pendingDocId)
          .get();

      if (!doc.exists) {
        throw 'Document introuvable';
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw 'Données introuvables';
      }

      final storedCode = data['verificationCode']?.toString() ?? '';

      if (storedCode == enteredCode) {
        await AuthService().createApprovedUser(
          _pendingDocId!,
          data['name'],
          data['phone'],
          data['password'],
        );

        await doc.reference.delete();

        try {
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null && FirebaseAuth.instance.currentUser != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .update({'fcmToken': token});
          }
        } catch (e) {
          debugPrint('Could not save FCM token: $e');
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
            (route) => false,
          );
        }
      } else {
        throw 'Code incorrect';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}