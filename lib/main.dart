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
      title: 'Agareb delivery',
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

// ---------- AuthWrapper (improved) ----------
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 2);

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
        final phone = _extractPhone(user);

        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey('role_$_retryCount'),
          future: _getUserRoleWithRetry(user.uid, phone),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnapshot.hasError) {
              // ✅ NO logout button – only retry
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Connexion au serveur impossible.\nVérifiez votre connexion internet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${roleSnapshot.error}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _retryCount++);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final role = roleSnapshot.data?['role'] ?? 'client';
            return role == 'worker'
                ? const WorkerHomeScreen()
                : const ClientHomeScreen();
          },
        );
      },
    );
  }

  String? _extractPhone(User user) {
    // Phone auth (if you ever switch to phone auth)
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return user.phoneNumber;
    }
    // Your current email-based phone storage
    if (user.email != null && user.email!.contains('@kartoucha.com')) {
      return user.email!.replaceAll('@kartoucha.com', '');
    }
    return null;
  }

  Future<Map<String, dynamic>> _getUserRoleWithRetry(
    String uid,
    String? phone,
  ) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        return await _getUserRole(uid, phone);
      } catch (e) {
        attempt++;
        if (attempt == _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempt);
      }
    }
    throw 'Impossible de récupérer le rôle après $_maxRetries tentatives.';
  }

  Future<Map<String, dynamic>> _getUserRole(String uid, String? phone) async {
    // 1. Check users collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      data['role'] = data['role'] ?? 'client';
      return data;
    }

    // 2. Check workers by phone
    if (phone != null && phone.isNotEmpty) {
      final workerQuery = await FirebaseFirestore.instance
          .collection('workers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (workerQuery.docs.isNotEmpty) {
        final workerData = workerQuery.docs.first.data();
        workerData['role'] = 'worker';
        return workerData;
      }
    }

    // 3. Create a fresh client document
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'phone': phone ?? '',
      'role': 'client',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return {'role': 'client', 'phone': phone ?? ''};
  }
}
