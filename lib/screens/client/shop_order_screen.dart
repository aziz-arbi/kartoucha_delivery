import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/operating_hours_utils.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../utils/zone_utils.dart';

class ShopOrderScreen extends StatefulWidget {
  final Position? position;
  const ShopOrderScreen({super.key, required this.position});

  @override
  State<ShopOrderScreen> createState() => _ShopOrderScreenState();
}

class _ShopOrderScreenState extends State<ShopOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _shopController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commande Shop')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shopController,
                decoration: const InputDecoration(
                  labelText: 'Magasin spécifique',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Liste de courses',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    final closed = await OperatingHoursUtils.isServiceClosed();
    if (closed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('service_closed_message', lang))),
        );
      }
      return;
    }

    if (widget.position != null) {
      final inZone = await ZoneUtils.isLocationInAnyActiveZone(
        widget.position!.latitude,
        widget.position!.longitude,
      );
      if (!inZone) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t('zone_not_covered', lang))));
        }
        return;
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('orders').add({
        'type': 'shop',
        'clientId': user!.uid,
        'clientPhone': _phoneController.text.trim(),
        'shop': _shopController.text.trim(),
        'orderDetails': _orderController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'location': GeoPoint(
          widget.position!.latitude,
          widget.position!.longitude,
        ),
        // ⚠️ NO assignedWorkerId here
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande envoyée, en attente de validation'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
