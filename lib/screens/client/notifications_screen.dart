import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('notifications', lang))),
        body: Center(child: Text(t('not_connected', lang))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('notifications', lang)),
        backgroundColor: const Color(0xFFFF5724),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('${t('error', lang)}: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text(t('no_notifications', lang)));
          }

          // Group by date
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['createdAt'] as Timestamp?;
            if (ts == null) continue;
            final date = ts.toDate();
            String key;
            final now = DateTime.now();
            if (date.year == now.year &&
                date.month == now.month &&
                date.day == now.day) {
              key = t('today', lang);
            } else if (date.year == now.year &&
                date.month == now.month &&
                date.day == now.day - 1) {
              key = t('yesterday', lang);
            } else {
              key = '${date.day}/${date.month}/${date.year}';
            }
            grouped.putIfAbsent(key, () => []).add(doc);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final key = grouped.keys.elementAt(index);
              final items = grouped[key]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: 8,
                      top: index == 0 ? 0 : 16,
                    ),
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                  ),
                  ...items.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? '';
                    final body = data['body'] ?? '';
                    final type = data['type'] ?? 'info';
                    final read = data['read'] ?? false;

                    IconData icon;
                    Color color;
                    switch (type) {
                      case 'order':
                        icon = Icons.shopping_bag;
                        color = const Color(0xFFFF5724);
                        break;
                      case 'ride':
                        icon = Icons.local_taxi;
                        color = const Color(0xFFFF8B3D);
                        break;
                      case 'promo':
                        icon = Icons.local_offer;
                        color = const Color(0xFFFFB84D);
                        break;
                      default:
                        icon = Icons.notifications;
                        color = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: read
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: const Color(0xFF4A4A4A),
                          ),
                        ),
                        subtitle: Text(
                          body,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: read
                            ? null
                            : Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5724),
                                  shape: BoxShape.circle,
                                ),
                              ),
                        onTap: () {
                          if (!read) {
                            doc.reference.update({'read': true});
                          }
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
