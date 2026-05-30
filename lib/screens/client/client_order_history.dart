import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class ClientOrderHistory extends StatefulWidget {
  const ClientOrderHistory({super.key});

  @override
  State<ClientOrderHistory> createState() => _ClientOrderHistoryState();
}

class _ClientOrderHistoryState extends State<ClientOrderHistory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'all',
    'food',
    'uber',
    'shop',
    'transport',
    'others',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Color _colorForType(String type) {
    switch (type) {
      case 'food':
        return const Color(0xFFFF5724);
      case 'uber':
        return const Color(0xFFFF8B3D);
      case 'shop':
        return const Color(0xFFFFB84D);
      case 'transport':
        return const Color(0xFF4A4A4A);
      default:
        return const Color(0xFFD33131);
    }
  }

  String _translateType(String type, String lang) {
    switch (type) {
      case 'food':
        return t('food', lang);
      case 'uber':
        return t('uber', lang);
      case 'shop':
        return t('shop', lang);
      case 'transport':
        return t('transport', lang);
      case 'others':
        return t('others', lang);
      default:
        return type;
    }
  }

  String _translateStatus(String status, String lang) {
    switch (status) {
      case 'pending':
        return t('status_pending', lang);
      case 'approved':
        return t('status_approved', lang);
      case 'assigned':
        return t('status_assigned', lang);
      case 'completed':
        return t('status_completed', lang);
      case 'cancelled':
        return t('status_cancelled', lang);
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'assigned':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text(t('not_connected', lang)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('history', lang)),
        backgroundColor: const Color(0xFFFF5724),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((tab) => Tab(text: t(tab, lang))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((tab) => _buildOrdersList(tab, user.uid, lang))
            .toList(),
      ),
    );
  }

  Widget _buildOrdersList(String filter, String uid, String lang) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('clientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    if (filter != 'all') {
      query = query.where('type', isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${t('error', lang)}: ${snapshot.error}'));
        }
        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) {
          return Center(child: Text(t('no_orders', lang)));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final type = order['type'] ?? 'others';
            final status = order['status'] ?? 'inconnu';
            final date = (order['createdAt'] as Timestamp?)?.toDate();

            final translatedType = _translateType(type, lang);
            final translatedStatus = _translateStatus(status, lang);
            final typeColor = _colorForType(type);
            final statusColor = _statusColor(status);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconForType(type), color: typeColor, size: 24),
                ),
                title: Row(
                  children: [
                    Text(
                      translatedType,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        translatedStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: date != null
                    ? Text(
                        '${date.day}/${date.month}/${date.year}  ${date.hour}:${date.minute}',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
