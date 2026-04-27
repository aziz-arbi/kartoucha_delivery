import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkerOrderHistory extends StatelessWidget {
  const WorkerOrderHistory({super.key});

  @override
  Widget build(BuildContext context) {
    // Worker userId is not stored directly; we need worker doc id.
    // We'll fetch the worker doc by phone, then query orders where assignedWorkerId == workerId.
    return FutureBuilder<String?>(
      future: _getWorkerId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final workerId = snapshot.data;
        if (workerId == null) return const Center(child: Text('Erreur'));
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('assignedWorkerId', isEqualTo: workerId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, orderSnapshot) {
            if (orderSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = orderSnapshot.data?.docs ?? [];
            if (orders.isEmpty)
              return const Center(child: Text('Aucune commande effectuée.'));
            return ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index].data() as Map<String, dynamic>;
                final status = order['status'] ?? 'inconnu';
                final type = order['type'] ?? '?';
                final date = (order['createdAt'] as Timestamp?)?.toDate();
                return ListTile(
                  leading: Icon(_iconForType(type)),
                  title: Text('$type - $status'),
                  subtitle: date != null
                      ? Text(
                          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}',
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<String?> _getWorkerId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final phone = user.email?.replaceAll('@kartoucha.com', '');
    if (phone == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    return doc.docs.isNotEmpty ? doc.docs.first.id : null;
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
}
