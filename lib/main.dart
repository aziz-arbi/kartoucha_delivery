import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/worker/worker_home.dart';
import 'screens/splash_screen.dart';

// ---------- 3jeja Brand Palette ----------
const Color orange = Color(0xFFFF5724);
const Color neonCarrot = Color(0xFFFF8B3D);
const Color texasRose = Color(0xFFFFB84D);
const Color tundora = Color(0xFF4A4A4A);
const Color persianRed = Color(0xFFD33131);

// ---------- Light Theme ----------
final lightTheme = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: orange,
    brightness: Brightness.light,
    primary: orange,
    secondary: neonCarrot,
    surface: Colors.white,
    error: persianRed,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: tundora,
  ),
  scaffoldBackgroundColor: const Color(0xFFF8F9FA),
  appBarTheme: const AppBarTheme(
    backgroundColor: orange,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: Colors.white,
    shadowColor: Colors.black12,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: orange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      elevation: 2,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: orange, width: 2),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: tundora, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: tundora, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(color: tundora, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: tundora),
    bodyMedium: TextStyle(color: tundora),
  ),
  iconTheme: const IconThemeData(color: orange),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: orange,
    unselectedItemColor: Colors.grey,
    backgroundColor: Colors.white,
    type: BottomNavigationBarType.fixed,
  ),
);

// ---------- Dark Theme ----------
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: orange,
    brightness: Brightness.dark,
    primary: orange,
    secondary: neonCarrot,
    surface: const Color(0xFF1E1E1E),
    error: persianRed,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFF2A2A2A),
    shadowColor: Colors.black26,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: orange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      elevation: 2,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2A2A2A),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: neonCarrot, width: 2),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: Colors.white70),
    bodyMedium: TextStyle(color: Colors.white70),
  ),
  iconTheme: const IconThemeData(color: orange),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: orange,
    unselectedItemColor: Colors.grey,
    backgroundColor: Color(0xFF1E1E1E),
    type: BottomNavigationBarType.fixed,
  ),
);

// ---------- App Entry (unchanged) ----------
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
      child: const _3jejaApp(),
    ),
  );
}

// ---------- App Root (renamed to 3jeja) ----------
class _3jejaApp extends StatelessWidget {
  const _3jejaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: '3jeja',
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AppStartup(),
    );
  }
}

// ---------- AppStartup: Splash → Force Update → AuthWrapper (unchanged) ----------
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      UpdateService.isUpdateRequired(),
    ]);

    if (!mounted) return;

    final updateRequired = await UpdateService.isUpdateRequired();
    if (updateRequired) {
      _showForceUpdateDialog();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  void _showForceUpdateDialog() async {
    final updateUrl = await UpdateService.getUpdateUrl();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Mise à jour requise'),
        content: const Text(
          'Une nouvelle version de l\'application est disponible.\n'
          'Veuillez la mettre à jour pour continuer.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final url = Uri.parse(updateUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

// ---------- AuthWrapper (unchanged) ----------
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
