import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../services/auth_service.dart';
import 'food_order_screen.dart';
import 'uber_order_screen.dart';
import 'shop_order_screen.dart';
import 'transport_order_screen.dart';
import 'others_order_screen.dart';
import 'offers_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    if (!_locationChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      OrderCategoriesScreen(position: _currentPosition),
      const OffersScreen(),
    ];

    final languageProvider = Provider.of<LanguageProvider>(context);
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
      endDrawer: _buildSettingsDrawer(context, lang, languageProvider),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: t('order', lang),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_offer),
            label: t('offers', lang),
          ),
        ],
      ),
    );
  }

  Drawer _buildSettingsDrawer(
    BuildContext context,
    String lang,
    LanguageProvider languageProvider,
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
            // Language switcher
            ListTile(
              leading: const Icon(Icons.language),
              // title: Text(t('change_language', lang)), (this is currently off beacause of the size problems and it bugs out the screen)
              trailing: DropdownButton<String>(
                value: languageProvider.locale.languageCode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ar', child: Text('Tounsi')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    languageProvider.setLanguage(value);
                  }
                },
              ),
            ),
            const Spacer(),
            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(t('logout', lang)),
              onTap: () {
                Navigator.pop(context);
                AuthService().signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class OrderCategoriesScreen extends StatelessWidget {
  final Position? position;
  const OrderCategoriesScreen({super.key, this.position});

  

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.locale.languageCode;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('workers')
                .where('status', isEqualTo: 'online')
                .snapshots(),
            builder: (context, snapshot) {
              int online = snapshot.data?.docs.length ?? 0;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delivery_dining, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      '$online ${t('workers_online', lang)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _CategoryCard(
                title: t('food', lang),
                icon: Icons.restaurant,
                color: Colors.orange,
                onTap: () async {
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    freshPosition = position;
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FoodOrderScreen(position: freshPosition),
                      ),
                    );
                  }
                },
              ),
              _CategoryCard(
                title: t('uber', lang),
                icon: Icons.local_taxi,
                color: Colors.blue,
                onTap: () async {
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    freshPosition = position;
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UberOrderScreen(position: freshPosition),
                      ),
                    );
                  }
                },
              ),
              _CategoryCard(
                title: t('shop', lang),
                icon: Icons.shopping_cart,
                color: Colors.purple,
                onTap: () async {
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    freshPosition = position;
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ShopOrderScreen(position: freshPosition),
                      ),
                    );
                  }
                },
              ),
              _CategoryCard(
                title: t('transport', lang),
                icon: Icons.local_shipping,
                color: Colors.brown,
                onTap: () async {
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    freshPosition = position;
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TransportOrderScreen(position: freshPosition),
                      ),
                    );
                  }
                },
              ),
              _CategoryCard(
                title: t('others', lang),
                icon: Icons.more_horiz,
                color: Colors.teal,
                onTap: () async {
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    freshPosition = position;
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OthersOrderScreen(position: freshPosition),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
