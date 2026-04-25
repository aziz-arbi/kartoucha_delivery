import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/operating_hours_utils.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../utils/zone_utils.dart';

class UberOrderScreen extends StatefulWidget {
  final Position? position;
  const UberOrderScreen({super.key, required this.position});

  @override
  State<UberOrderScreen> createState() => _UberOrderScreenState();
}

class _UberOrderScreenState extends State<UberOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _destinationController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande Uber')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Téléphone'),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(labelText: 'Point B (destination)'),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                child: Text('Confirmer'),
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
        'type': 'uber',
        'clientId': user!.uid,
        'clientPhone': _phoneController.text.trim(),
        'destination': _destinationController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'location': GeoPoint(
          widget.position!.latitude,
          widget.position!.longitude,
        ),
        // ⚠️ NO assignedWorkerId here
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande envoyée')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}