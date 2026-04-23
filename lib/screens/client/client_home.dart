import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import 'food_order_screen.dart';
import 'uber_order_screen.dart';
import 'shop_order_screen.dart';
import 'transport_order_screen.dart';
import 'others_order_screen.dart';
import 'offers_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> with WidgetsBindingObserver {
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

  // Detect when app resumes (e.g., after returning from settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_locationChecked) {
      _checkLocationPermission();
    }
  }

  Future<void> _checkLocationPermission() async {
    // 1. Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    // 2. Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Request permission (system popup will appear)
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // User denied once – we can ask again (system popup will show next time)
        _showLocationDeniedDialog(isPermanent: false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User denied permanently – must go to settings
      _showLocationDeniedDialog(isPermanent: true);
      return;
    }

    // 3. Permission granted – get position
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _locationChecked = true;
      });
    } catch (e) {
      // Could not get position (e.g., poor GPS signal)
      _showLocationErrorDialog();
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Activer la localisation'),
        content: const Text('Veuillez activer la localisation dans les paramètres de votre téléphone.'),
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
        content: Text(isPermanent
            ? 'Permission de localisation refusée définitivement.\nVeuillez l\'activer dans les paramètres.'
            : 'La localisation est nécessaire pour utiliser l\'application.'),
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
        content: const Text('Impossible d\'obtenir votre position. Vérifiez votre connexion GPS.'),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = [
      OrderCategoriesScreen(position: _currentPosition),
      const OffersScreen(),
    ];
    
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kartoucha Delivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Commander'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Offres'),
        ],
      ),
    );
  }
}

// Keep OrderCategoriesScreen and _CategoryCard unchanged from previous version
class OrderCategoriesScreen extends StatelessWidget {
  final Position? position;
  const OrderCategoriesScreen({super.key, this.position});

  @override
  Widget build(BuildContext context) {
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
                      '$online livreur(s) en ligne',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                title: 'Food',
                icon: Icons.restaurant,
                color: Colors.orange,
                onTap: () async {
                  // Fetch fresh location before ordering
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    // Fallback to cached position
                    freshPosition = position;
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FoodOrderScreen(position: freshPosition)),
                    );
                  }
                },
              ),
              _CategoryCard(
                title: 'Uber',
                icon: Icons.local_taxi,
                color: Colors.blue,
                onTap: () async {
                  // Fetch fresh location before ordering
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    // Fallback to cached position
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
                title: 'Shop',
                icon: Icons.shopping_cart,
                color: Colors.purple,
                onTap: () async {
                  // Fetch fresh location before ordering
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    // Fallback to cached position
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
                title: 'Transport',
                icon: Icons.local_shipping,
                color: Colors.brown,
                onTap: () async {
                  // Fetch fresh location before ordering
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    // Fallback to cached position
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
                title: 'Autres',
                icon: Icons.more_horiz,
                color: Colors.teal,
                onTap: () async {
                  // Fetch fresh location before ordering
                  Position? freshPosition;
                  try {
                    freshPosition = await Geolocator.getCurrentPosition();
                  } catch (e) {
                    // Fallback to cached position
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