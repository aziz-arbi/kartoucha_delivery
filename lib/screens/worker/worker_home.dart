import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/auth_service.dart';
import 'order_details_screen.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import 'package:provider/provider.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  String? _workerId;
  Map<String, dynamic>? _workerData;
  bool _isOnline = false;

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

      // Save FCM token for this worker
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
    final lang = languageProvider.locale.languageCode;


    return Scaffold(
      appBar: AppBar(
        title: Text(t('title', lang)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(_isOnline ? 'En ligne' : 'Hors ligne'),
                Switch(
                  value: _isOnline,
                  onChanged: (_) => _toggleOnlineStatus(),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: _isOnline
          ? _buildOrdersList(specialties)
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.power_settings_new, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Vous êtes hors ligne', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 8),
                  Text('Activez le bouton pour recevoir des commandes'),
                ],
              ),
            ),
    );
  }

  Widget _buildOrdersList(List<String> specialties) {
    debugPrint('🔔 Building orders list. Specialties: $specialties');

    if (specialties.isEmpty) {
      return const Center(
        child: Text('Aucune spécialité assignée. Contactez l\'admin.'),
      );
    }

    Query query = FirebaseFirestore.instance.collection('orders');
    query = query.where('status', isEqualTo: 'approved');
    query = query.where('type', whereIn: specialties);
    query = query.where('assignedWorkerId', isNull: true);
    query = query.orderBy('createdAt', descending: true);

    debugPrint('📡 Query: orders where status==approved, type in $specialties, assignedWorkerId==null, orderBy createdAt desc');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'approved')
          .where('type', whereIn: specialties)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint(
          '📡 Stream update: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}',
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('🔥 Stream error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  const Text('Vérifiez la console pour plus de détails.'),
                ],
              ),
            ),
          );
        }

        final allOrders = snapshot.data?.docs ?? [];

        // Filter out orders that already have an assignedWorkerId
        final filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final assigned = data['assignedWorkerId'];
          return assigned == null || assigned == '';
        }).toList();

        debugPrint(
          '📦 All approved orders of matching types: ${allOrders.length}, after null-check filter: ${filteredOrders.length}',
        );

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
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
        final orderSnap = await transaction.get(orderRef);

        if (!orderSnap.exists) throw 'Commande introuvable';
        if (orderSnap.data()?['status'] != 'approved') {
          throw 'Commande déjà prise';
        }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                child: const Text('Accepter la commande'),
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