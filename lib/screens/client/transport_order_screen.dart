import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/operating_hours_utils.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../utils/zone_utils.dart';

class TransportOrderScreen extends StatefulWidget {
  final Position? position;
  const TransportOrderScreen({super.key, required this.position});

  @override
  State<TransportOrderScreen> createState() => _TransportOrderScreenState();
}

class _TransportOrderScreenState extends State<TransportOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _destinationController = TextEditingController();
  final _whatToTransportController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande Transport')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(
                  labelText: 'Point B (destination)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _whatToTransportController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Ce qui sera transporté',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Confirmer la commande'),
                ),
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
        'type': 'transport',
        'clientId': user!.uid,
        'clientPhone': _phoneController.text.trim(),
        'destination': _destinationController.text.trim(),
        'whatToTransport': _whatToTransportController.text.trim(),
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
        SnackBar(content: Text('Commande envoyée, en attente de validation')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}