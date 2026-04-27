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

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  String? _workerId;
  Map<String, dynamic>? _workerData;
  bool _isOnline = false;

  // 🔁 Stores the previous order count to detect new orders → vibration
  int _previousOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _loadWorkerData();
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
      appBar: AppBar(
        title: Text(t('worker_title', lang)),
        actions: [
          // Settings icon → opens end drawer
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
      body: _isOnline
          ? _buildOrdersList(specialties)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.power_settings_new, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    t('you_are_offline', lang),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(t('activate_button', lang)),
                ],
              ),
            ),
    );
  }

  // ------ Worker's settings drawer ------
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
            // Language switcher
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(t('change_language', lang)),
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
            // Theme switcher
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(t('theme', lang)),
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
            // Online / Offline toggle
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
            // Worker Order History
            ListTile(
              leading: const Icon(Icons.history),
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

  // Helper methods for theme mode conversion
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

  Widget _buildOrdersList(List<String> specialties) {
    debugPrint('🔔 Building orders list. Specialties: $specialties');

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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final allOrders = snapshot.data?.docs ?? [];
        final filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final assigned = data['assignedWorkerId'];
          return assigned == null || assigned == '';
        }).toList();

        // 🟢 Vibration when a brand new order appears
        if (filteredOrders.isNotEmpty && _previousOrderCount == 0) {
          Vibration.vibrate(duration: 200); // short buzz
        }
        // Update previous count for next rebuild
        _previousOrderCount = filteredOrders.length;

        if (filteredOrders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucune commande disponible'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index].data() as Map<String, dynamic>?;
            final orderId = filteredOrders[index].id;
            if (order == null) return const SizedBox.shrink();

            return _OrderCard(
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

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String orderId;
  final String workerId;
  final VoidCallback onAccept;

  const _OrderCard({
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
        typeColor = Colors.orange;
        break;
      case 'uber':
        typeIcon = Icons.local_taxi;
        typeColor = Colors.blue;
        break;
      case 'shop':
        typeIcon = Icons.shopping_cart;
        typeColor = Colors.purple;
        break;
      case 'transport':
        typeIcon = Icons.local_shipping;
        typeColor = Colors.brown;
        break;
      default:
        typeIcon = Icons.help;
        typeColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('📞 $clientPhone'),
            const SizedBox(height: 4),
            Text(_getOrderSummary(order)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(t('accept_order', lang)),
              ),
            ),
          ],
        ),
      ),
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
