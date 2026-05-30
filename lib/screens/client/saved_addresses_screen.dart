import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty || address.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'savedAddresses': FieldValue.arrayUnion([
        {'name': name, 'address': address},
      ]),
    });

    _nameController.clear();
    _addressController.clear();
    Navigator.pop(context);
    setState(() {});
  }

  Future<void> _deleteAddress(Map<String, dynamic> addr) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'savedAddresses': FieldValue.arrayRemove([addr]),
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('saved_addresses', lang))),
        body: Center(child: Text(t('not_connected', lang))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('saved_addresses', lang)),
        backgroundColor: const Color(0xFFFF5724),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, lang),
        backgroundColor: const Color(0xFFFF5724),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(t('no_addresses', lang)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final addresses = List<Map<String, dynamic>>.from(
            data['savedAddresses'] ?? [],
          );

          if (addresses.isEmpty) {
            return Center(child: Text(t('no_addresses', lang)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5724).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFFF5724),
                    ),
                  ),
                  title: Text(
                    addr['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(addr['address'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFD33131)),
                    onPressed: () => _deleteAddress(addr),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('add_address', lang)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '${t('name', lang)} (ex: ${t('home', lang)})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('address', lang),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel', lang)),
          ),
          ElevatedButton(
            onPressed: _addAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5724),
            ),
            child: Text(t('save', lang)),
          ),
        ],
      ),
    );
  }
}
