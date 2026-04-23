import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kartoucha_delivery/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/worker/worker_home.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final languageProvider = LanguageProvider();  // lowercase variable name
  await languageProvider.loadLanguage();        // load saved language
  
  await NotificationService.initialize();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => languageProvider,
      child: const KartouchaApp(),
    ),
  );
}

class KartouchaApp extends StatelessWidget {
  const KartouchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'Kartoucha Delivery',
          debugShowCheckedModeBanner: false,
          locale: languageProvider.locale,
          theme: ThemeData(
            primarySwatch: Colors.red,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;
        final phone = user.email?.replaceAll('@kartoucha.com', '');

        // Use a single FutureBuilder to determine role
        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserRole(user.uid, phone),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: ${roleSnapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Se déconnecter'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final role = roleSnapshot.data?['role'] ?? 'client';
            final screen = role == 'worker' ? const WorkerHomeScreen() : const ClientHomeScreen();

            return screen;
          },
        );
      },
    );
  }

  /// Determines the user's role by checking 'users' collection first, then 'workers'.
  Future<Map<String, dynamic>> _getUserRole(String uid, String? phone) async {
    try {
      print('🔍 Getting role for uid: $uid, phone: $phone');
    
      // 1. Check users collection
      print('📡 Checking users collection...');
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      print('📡 Users doc exists: ${userDoc.exists}');
    
      if (userDoc.exists) {
        final data = userDoc.data()!;
        data['role'] = data['role'] ?? 'client';
        print('✅ Found in users, role: ${data['role']}');
        return data;
      }

      // 2. Check workers collection by phone
      if (phone != null && phone.isNotEmpty) {
        print('📡 Checking workers collection for phone: $phone');
        final workerQuery = await FirebaseFirestore.instance
            .collection('workers')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

        print('📡 Workers query returned ${workerQuery.docs.length} docs');
      
        if (workerQuery.docs.isNotEmpty) {
          final workerData = workerQuery.docs.first.data();
          workerData['role'] = 'worker';
          print('✅ Found in workers, role: worker');
          return workerData;
        }
      }

      // 3. Not found – sign out
      print('❌ Not found in users or workers, signing out');
      await FirebaseAuth.instance.signOut();
      throw 'Compte non trouvé. Veuillez contacter l\'administrateur.';
    } catch (e) {
      print('🔥 Error in _getUserRole: $e');
      rethrow;
    }
  }
}