import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/translations.dart';
import '../../services/auth_service.dart';
import 'food_order_screen.dart';
import 'uber_order_screen.dart';
import 'shop_order_screen.dart';
import 'transport_order_screen.dart';
import 'others_order_screen.dart';
import 'offers_screen.dart';
import 'client_order_history.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Position? _currentPosition;
  bool _locationChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_locationChecked) {
      _checkLocationPermission();
    }
  }

  // ---------- Location handling (unchanged) ----------
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationDeniedDialog(isPermanent: false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationDeniedDialog(isPermanent: true);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _locationChecked = true;
      });
    } catch (e) {
      _showLocationErrorDialog();
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Activer la localisation'),
        content: const Text(
          'Veuillez activer la localisation dans les paramètres de votre téléphone.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Paramètres'),
          ),
          TextButton(
            onPressed: () => AuthService().signOut(),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  void _showLocationDeniedDialog({required bool isPermanent}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Localisation requise'),
        content: Text(
          isPermanent
              ? 'Permission de localisation refusée définitivement.\nVeuillez l\'activer dans les paramètres.'
              : 'La localisation est nécessaire pour utiliser l\'application.',
        ),
        actions: [
          if (isPermanent)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Geolocator.openAppSettings();
              },
              child: const Text('Paramètres'),
            ),
          if (!isPermanent)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _checkLocationPermission();
              },
              child: const Text('Réessayer'),
            ),
          TextButton(
            onPressed: () => AuthService().signOut(),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Erreur de localisation'),
        content: const Text(
          'Impossible d\'obtenir votre position. Vérifiez votre connexion GPS.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _checkLocationPermission();
            },
            child: const Text('Réessayer'),
          ),
          TextButton(
            onPressed: () => AuthService().signOut(),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
  // ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_locationChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      OrderCategoriesScreen(position: _currentPosition),
      const OffersScreen(),
      const ClientOrderHistory(),
    ];

    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = languageProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('title', lang)),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildSettingsDrawer(
        context,
        lang,
        languageProvider,
        themeProvider,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFFFF5724),
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: t('order', lang),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_offer),
            label: t('offers', lang),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: t('history', lang),
          ),
        ],
      ),
    );
  }

  // ------ Settings drawer (unchanged) ------
  Drawer _buildSettingsDrawer(
    BuildContext context,
    String lang,
    LanguageProvider languageProvider,
    ThemeProvider themeProvider,
  ) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.person, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              t('settings', lang),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(''),
              trailing: DropdownButton<String>(
                value: languageProvider.locale.languageCode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ar', child: Text('Tounsi')),
                ],
                onChanged: (value) {
                  if (value != null) languageProvider.setLanguage(value);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(' '),
              trailing: DropdownButton<String>(
                value: _themeModeToKey(themeProvider.mode),
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(
                    value: 'light',
                    child: Text(t('light', lang)),
                  ),
                  DropdownMenuItem(value: 'dark', child: Text(t('dark', lang))),
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(t('system_default', lang)),
                  ),
                ],
                onChanged: (value) {
                  if (value != null)
                    themeProvider.setTheme(_keyToThemeMode(value));
                },
              ),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFD33131)),
              title: Text(t('logout', lang)),
              onTap: () {
                Navigator.pop(context);
                AuthService().signOut();
              },
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: Text('Privacy Policy'),
              onTap: () async {
                final url =
                    'https://your-deployed-url/privacy_policy.html'; // replace with your real URL
                if (await canLaunchUrl(Uri.parse(url))) {
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeToKey(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }

  AppThemeMode _keyToThemeMode(String key) {
    switch (key) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }
}

// ---------- ORDER CATEGORIES SCREEN ----------
class OrderCategoriesScreen extends StatelessWidget {
  final Position? position;
  const OrderCategoriesScreen({super.key, this.position});

  final List<Map<String, dynamic>> categories = const [
    {
      'title': 'food',
      'image': 'assets/images/food.jpeg',
      'icon': Icons.restaurant,
      'color': Color(0xFFFF5724),
    },
    {
      'title': 'uber',
      'image': 'assets/images/uber.jpg',
      'icon': Icons.local_taxi,
      'color': Color(0xFFFF8B3D),
    },
    {
      'title': 'shop',
      'image': 'assets/images/shop.png',
      'icon': Icons.shopping_cart,
      'color': Color(0xFFFFB84D),
    },
    {
      'title': 'transport',
      'image': 'assets/images/transport.jpeg',
      'icon': Icons.local_shipping,
      'color': Color(0xFF4A4A4A),
    },
    {
      'title': 'others',
      'image': 'assets/images/others.jpeg',
      'icon': Icons.more_horiz,
      'color': Color(0xFFD33131),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('workers')
              .where('status', isEqualTo: 'online')
              .snapshots(),
          builder: (context, snapshot) {
            int online = snapshot.data?.docs.length ?? 0;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade900 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delivery_dining,
                    color: isDark ? Colors.greenAccent : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$online ${t('workers_online', lang)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _AnimatedCategoryCard(
                index: index,
                title: t(cat['title'], lang),
                image: cat['image'],
                icon: cat['icon'],
                color: cat['color'],
                onTap: () async {
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (_) {
                    freshPosition = position;
                  }
                  if (context.mounted) {
                    Widget screen;
                    switch (cat['title']) {
                      case 'food':
                        screen = FoodOrderScreen(position: freshPosition);
                        break;
                      case 'uber':
                        screen = UberOrderScreen(position: freshPosition);
                        break;
                      case 'shop':
                        screen = ShopOrderScreen(position: freshPosition);
                        break;
                      case 'transport':
                        screen = TransportOrderScreen(position: freshPosition);
                        break;
                      case 'others':
                        screen = OthersOrderScreen(position: freshPosition);
                        break;
                      default:
                        screen = FoodOrderScreen(position: freshPosition);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => screen),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------- CORRECTED CARD WITH ROUNDED LEFT + SMALL RIGHT CORNERS ----------
class _AnimatedCategoryCard extends StatelessWidget {
  final int index;
  final String title;
  final String image;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedCategoryCard({
    required this.index,
    required this.title,
    required this.image,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double leftRadius = 30;
    const double rightRadius = 12;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(leftRadius),
                  bottomLeft: const Radius.circular(leftRadius),
                  topRight: const Radius.circular(rightRadius),
                  bottomRight: const Radius.circular(rightRadius),
                ),
                child: Container(
                  height: 130,
                  // The shadow is drawn here, but the container has no clipping.
                  // We add another container inside that actually clips.
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(leftRadius),
                      bottomLeft: const Radius.circular(leftRadius),
                      topRight: const Radius.circular(rightRadius),
                      bottomRight: const Radius.circular(rightRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(leftRadius),
                      bottomLeft: const Radius.circular(leftRadius),
                      topRight: const Radius.circular(rightRadius),
                      bottomRight: const Radius.circular(rightRadius),
                    ),
                    child: Row(
                      children: [
                        // Left image (70%)
                        Expanded(
                          flex: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(image),
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              ),
                              color: color.withOpacity(0.3),
                            ),
                          ),
                        ),
                        // Right coloured panel (30%)
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withOpacity(0.7)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 4,
                                        color: Colors.black26,
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
              ),
            ),
          ),
        );
      },
    );
  }
}
