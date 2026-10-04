import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user is already logged in
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with phone and password (custom implementation)
  Future<User?> signInWithPhoneAndPassword(String phone, String password) async {
    try {
      // We'll use email/password behind the scenes but with phone as email
      String email = '$phone@kartoucha.com';
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Register a new user. Verification is automatic: the WhatsApp
  // verification service generates and sends the 6-digit code.
  Future<void> registerUser({
    required String name,
    required String phone,
    required String password,
  }) async {
    await _firestore.collection('pending_users').add({
      'name': name,
      'phone': phone,
      'password': password,
      'createdAt': FieldValue.serverTimestamp(),

      // Kept for compatibility with the existing admin dashboard/schema.
      // No manual admin approval is required anymore.
      'approved': true,
      'denied': false,

      // The WhatsApp service watches this state and sends the code.
      'verificationStatus': 'pending',
      'verificationCode': null,
      'verificationSentAt': null,
      'verificationExpiresAt': null,
    });
  }

  // After verification, create the actual Firebase Auth account
  Future<void> createApprovedUser(String userId, String name, String phone, String password) async {
    String email = '$phone@kartoucha.com';
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Update display name
      await _auth.currentUser?.updateDisplayName(name);
      
      // Store user profile in Firestore
      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'name': name,
        'phone': phone,
        'role': 'client',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}