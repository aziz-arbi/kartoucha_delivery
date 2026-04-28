import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientOrderHistory extends StatelessWidget {
  const ClientOrderHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Non connecté'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('clientId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('Aucune commande passée.'));
        }
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
                      '${date.day}/${date.month}/${date.year}  ${date.hour}:${date.minute}',
                    )
                  : null,
            );
          },
        );
      },
    );
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
