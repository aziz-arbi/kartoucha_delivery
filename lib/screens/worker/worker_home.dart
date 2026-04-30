import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/translations.dart';
import '../../services/auth_service.dart';
import 'order_details_screen.dart';
import 'worker_order_history.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with SingleTickerProviderStateMixin {
  String? _workerId;
  Map<String, dynamic>? _workerData;
  bool _isOnline = false;
  int _previousOrderCount = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _loadWorkerData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .where('phone', isEqualTo: user.email?.replaceAll('@kartoucha.com', ''))
        .get();

    if (doc.docs.isNotEmpty) {
      final data = doc.docs.first.data();
      setState(() {
        _workerId = doc.docs.first.id;
        _workerData = data;
        _isOnline = data['status'] == 'online';
      });

      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null && _workerId != null) {
          await FirebaseFirestore.instance
              .collection('workers')
              .doc(_workerId)
              .update({'fcmToken': token});
        }
      } catch (e) {
        debugPrint('Could not save worker FCM token: $e');
      }
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_workerId == null) return;
    final newStatus = _isOnline ? 'offline' : 'online';
    await FirebaseFirestore.instance
        .collection('workers')
        .doc(_workerId)
        .update({'status': newStatus});
    setState(() => _isOnline = !_isOnline);
  }

  @override
  Widget build(BuildContext context) {
    if (_workerData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final specialties = List<String>.from(_workerData!['specialties'] ?? []);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = languageProvider.locale.languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delivery_dining),
            const SizedBox(width: 8),
            Text(t('worker_title', lang)),
          ],
        ),
        actions: [
          // Online status pill
          GestureDetector(
            onTap: _toggleOnlineStatus,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _isOnline
                    ? Colors.green.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isOnline ? Colors.green : Colors.grey,
                  width: 1.5,
                ),
              ),
              child: Text(
                _isOnline
                    ? t('worker_status_online', lang)
                    : t('worker_status_offline', lang),
                style: TextStyle(
                  color: _isOnline ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Settings icon
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isOnline
            ? _buildOrdersList(specialties)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF8B3D).withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.power_settings_new,
                        size: 64,
                        color: Color(0xFFFF8B3D),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t('you_are_offline', lang),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('activate_button', lang),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ------ Settings drawer ------
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
            Icon(
              Icons.person,
              size: 60,
              color: const Color(0xFFFF5724).withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              t('settings', lang),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // Language
            ListTile(
              leading: const Icon(Icons.language, color: Color(0xFFFF5724)),
              title: Text(' '),
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
            // Theme
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Color(0xFFFF8B3D)),
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
            // Online toggle
            SwitchListTile(
              secondary: Icon(
                _isOnline ? Icons.toggle_on : Icons.toggle_off,
                color: _isOnline ? Colors.green : Colors.grey,
              ),
              title: Text(
                _isOnline
                    ? t('worker_status_online', lang)
                    : t('worker_status_offline', lang),
              ),
              value: _isOnline,
              onChanged: (_) => _toggleOnlineStatus(),
            ),
            // Order history
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFFFFB84D)),
              title: Text(t('history', lang)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WorkerOrderHistory()),
                );
              },
            ),
            const Spacer(),
            // Logout
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

  // ------ Orders list with animation ------
  Widget _buildOrdersList(List<String> specialties) {
    if (specialties.isEmpty) {
      return const Center(
        child: Text('Aucune spécialité assignée. Contactez l\'admin.'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'approved')
          .where('type', whereIn: specialties)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final allOrders = snapshot.data?.docs ?? [];
        final filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final assigned = data['assignedWorkerId'];
          return assigned == null || assigned == '';
        }).toList();

        // Vibration when new order appears
        if (filteredOrders.isNotEmpty && _previousOrderCount == 0) {
          Vibration.vibrate(duration: 200);
        }
        _previousOrderCount = filteredOrders.length;

        if (filteredOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFB84D).withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.inbox,
                    size: 64,
                    color: Color(0xFFFFB84D),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucune commande disponible',
                  style: TextStyle(color: Color(0xFF4A4A4A)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index].data() as Map<String, dynamic>?;
            final orderId = filteredOrders[index].id;
            if (order == null) return const SizedBox.shrink();

            return _AnimatedOrderCard(
              index: index,
              order: order,
              orderId: orderId,
              workerId: _workerId!,
              onAccept: () => _acceptOrder(orderId),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId);
        final orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) throw 'Commande introuvable';
        if (orderSnap.data()?['status'] != 'approved')
          throw 'Commande déjà prise';

        transaction.update(orderRef, {
          'status': 'assigned',
          'assignedWorkerId': _workerId,
          'assignedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(
          FirebaseFirestore.instance.collection('workers').doc(_workerId),
          {'currentOrderId': orderId},
        );
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}

// ------ Animated order card ------
class _AnimatedOrderCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> order;
  final String orderId;
  final String workerId;
  final VoidCallback onAccept;

  const _AnimatedOrderCard({
    required this.index,
    required this.order,
    required this.orderId,
    required this.workerId,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final type = order['type'] ?? 'inconnu';
    final clientPhone = order['clientPhone'] ?? 'N/A';
    final createdAt = order['createdAt'] != null
        ? (order['createdAt'] as Timestamp).toDate()
        : null;
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    IconData typeIcon;
    Color typeColor;
    switch (type) {
      case 'food':
        typeIcon = Icons.restaurant;
        typeColor = const Color(0xFFFF5724);
        break;
      case 'uber':
        typeIcon = Icons.local_taxi;
        typeColor = const Color(0xFFFF8B3D);
        break;
      case 'shop':
        typeIcon = Icons.shopping_cart;
        typeColor = const Color(0xFFFFB84D);
        break;
      case 'transport':
        typeIcon = Icons.local_shipping;
        typeColor = const Color(0xFF4A4A4A);
        break;
      default:
        typeIcon = Icons.help;
        typeColor = const Color(0xFFD33131);
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Card(
                elevation: 4,
                shadowColor: typeColor.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: typeColor.withOpacity(0.1),
                            ),
                            child: Icon(typeIcon, color: typeColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: typeColor,
                            ),
                          ),
                          const Spacer(),
                          if (createdAt != null)
                            Text(
                              '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 18,
                            color: Color(0xFF4A4A4A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            clientPhone,
                            style: const TextStyle(color: Color(0xFF4A4A4A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getOrderSummary(order),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: typeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            t('accept_order', lang),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        );
      },
    );
  }

  String _getOrderSummary(Map<String, dynamic> order) {
    switch (order['type']) {
      case 'food':
        return '🍔 ${order['orderDetails'] ?? ''}';
      case 'uber':
        return '🚗 Destination: ${order['destination'] ?? ''}';
      case 'shop':
        return '🛒 ${order['shop'] ?? ''}: ${order['orderDetails'] ?? ''}';
      case 'transport':
        return '🚛 ${order['whatToTransport'] ?? ''} → ${order['destination'] ?? ''}';
      default:
        return '📦 ${order['whatIsIt'] ?? ''}';
    }
  }
}
