import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'notifications_screen.dart';
import 'account_screen.dart'; // new Account screen
import 'order_tracking_screen.dart';

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

    // 4 functional tabs: Home(0), History(1), Offers(2), Account(3)
    final screens = [
      OrderCategoriesScreen(position: _currentPosition),
      const ClientOrderHistory(),
      const OffersScreen(),
      const AccountScreen(),
    ];

    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('3jeja'),
        actions: [
          // Only notification bell – no settings icon
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(context, lang),
    );
  }

  // ---------- Custom bottom bar with centered floating logo ----------
  Widget _buildBottomNav(BuildContext context, String lang) {
    // The items array includes 5 slots: Home, History, (placeholder), Offers, Account
    final items = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home),
        label: t('home', lang),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.receipt_long),
        label: t('history', lang),
      ),
      // Placeholder for center – invisible, so the logo appears on top
      const BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
      BottomNavigationBarItem(
        icon: const Icon(Icons.local_offer),
        label: t('offers', lang),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person),
        label: t('account', lang),
      ),
    ];

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        BottomNavigationBar(
          currentIndex: _selectedIndex < 2
              ? _selectedIndex
              : _selectedIndex + 1, // skip center
          onTap: (index) {
            if (index == 2)
              return; // center tapped – handled by the floating button
            setState(() {
              _selectedIndex = index > 2 ? index - 1 : index;
            });
          },
          selectedItemColor: const Color(0xFFFF5724),
          unselectedItemColor: Colors.grey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          type: BottomNavigationBarType.fixed,
          items: items,
        ),
        // Floating 3jeja logo button
        Positioned(
          top: -30, // half outside
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = 0);
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFFF5724),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF5724),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png', // your 3jeja logo – use a white version if possible
                  width: 40,
                  height: 40,
                  color: Colors.white,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.delivery_dining,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- OrderCategoriesScreen (unchanged from your existing code) ----------
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

  IconData _iconForType(String type) {
    switch (type) {
      case 'food':
        return Icons.restaurant;
      case 'uber':
        return Icons.local_taxi;
      case 'shop':
        return Icons.shopping_cart;
      case 'transport':
        return Icons.local_shipping;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        // 1. Workers online banner
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

        // 2. Active order card (translated)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('clientId', isEqualTo: currentUid)
              .where('status', whereNotIn: ['completed', 'cancelled'])
              .orderBy('createdAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            final orders = snapshot.data?.docs ?? [];
            if (orders.isEmpty) return const SizedBox.shrink();

            final orderData = orders.first.data() as Map<String, dynamic>;
            final orderId = orders.first.id;
            final type = orderData['type'] ?? 'food';
            final status = orderData['status'] ?? 'pending';

            String statusText;
            Color statusColor;
            switch (status) {
              case 'pending':
                statusText = t('status_pending', lang);
                statusColor = Colors.orange;
                break;
              case 'approved':
                statusText = t('status_approved', lang);
                statusColor = Colors.blue;
                break;
              case 'assigned':
                statusText = t('status_assigned', lang);
                statusColor = Colors.green;
                break;
              default:
                statusText = status;
                statusColor = Colors.grey;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconForType(type),
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t('your_order', lang)} ${t(type, lang)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(orderId: orderId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5724),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      t('track', lang),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 3. Scrollable category list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

// ---------- _AnimatedCategoryCard (unchanged) ----------
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
