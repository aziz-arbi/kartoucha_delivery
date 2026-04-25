import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/worker/worker_home.dart';

// ---------- Light Theme ----------
final lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.red,
  scaffoldBackgroundColor: const Color(0xFFF8F9FA),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.red,
    brightness: Brightness.light,
  ),
);

// ---------- Dark Theme ----------
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.red,
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: const Color(0xFF1E1E1E),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.red,
    brightness: Brightness.dark,
  ),
);

// ---------- App Entry ----------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final languageProvider = LanguageProvider();
  await languageProvider.loadLanguage();

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  await NotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => languageProvider),
        ChangeNotifierProvider(create: (_) => themeProvider),
      ],
      child: const KartouchaApp(),
    ),
  );
}

// ---------- App Root ----------
class KartouchaApp extends StatelessWidget {
  const KartouchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Kartoucha Delivery',
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
    );
  }
}

// ---------- AuthWrapper (unchanged, only print -> debugPrint) ----------
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;
        final phone = user.email?.replaceAll('@kartoucha.com', '');

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserRole(user.uid, phone),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
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
            final screen = role == 'worker'
                ? const WorkerHomeScreen()
                : const ClientHomeScreen();

            return screen;
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getUserRole(String uid, String? phone) async {
    try {
      debugPrint('🔍 Getting role for uid: $uid, phone: $phone');

      debugPrint('📡 Checking users collection...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      debugPrint('📡 Users doc exists: ${userDoc.exists}');

      if (userDoc.exists) {
        final data = userDoc.data()!;
        data['role'] = data['role'] ?? 'client';
        debugPrint('✅ Found in users, role: ${data['role']}');
        return data;
      }

      if (phone != null && phone.isNotEmpty) {
        debugPrint('📡 Checking workers collection for phone: $phone');
        final workerQuery = await FirebaseFirestore.instance
            .collection('workers')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

        debugPrint('📡 Workers query returned ${workerQuery.docs.length} docs');

        if (workerQuery.docs.isNotEmpty) {
          final workerData = workerQuery.docs.first.data();
          workerData['role'] = 'worker';
          debugPrint('✅ Found in workers, role: worker');
          return workerData;
        }
      }

      debugPrint('❌ Not found in users or workers, signing out');
      await FirebaseAuth.instance.signOut();
      throw 'Compte non trouvé. Veuillez contacter l\'administrateur.';
    } catch (e) {
      debugPrint('🔥 Error in _getUserRole: $e');
      rethrow;
    }
  }
}
