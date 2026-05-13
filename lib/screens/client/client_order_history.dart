import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class ClientOrderHistory extends StatelessWidget {
  const ClientOrderHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text(t('not_connected', lang)));
    }

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
          return Center(child: Text('${t('error', lang)}: ${snapshot.error}'));
        }
        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) {
          return Center(child: Text(t('no_orders', lang)));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final status = order['status'] ?? 'inconnu';
            final type = order['type'] ?? '?';
            final date = (order['createdAt'] as Timestamp?)?.toDate();

            // Translate status and type
            final translatedStatus = t('status_$status', lang);
            final translatedType = t(type, lang);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(_iconForType(type)),
                title: Text('$translatedType - $translatedStatus'),
                subtitle: date != null
                    ? Text(
                        '${date.day}/${date.month}/${date.year}  ${date.hour}:${date.minute}',
                      )
                    : null,
              ),
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
