import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../utils/operating_hours_utils.dart';
import '../../utils/zone_utils.dart';

class OthersOrderScreen extends StatefulWidget {
  final Position? position;
  const OthersOrderScreen({super.key, required this.position});

  @override
  State<OthersOrderScreen> createState() => _OthersOrderScreenState();
}

class _OthersOrderScreenState extends State<OthersOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fromWhereController = TextEditingController();
  final _whatIsItController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(t('others', lang))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: t('phone', lang),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? t('required_field', lang) : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fromWhereController,
                decoration: InputDecoration(
                  labelText: t('from_where', lang),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? t('required_field', lang) : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatIsItController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: t('what_is_this', lang),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? t('required_field', lang) : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          t('confirm_order', lang),
                          style: const TextStyle(fontSize: 18),
                        ),
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

    // 1️⃣ Check operating hours
    final closed = await OperatingHoursUtils.isServiceClosed();
    if (closed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('service_closed_message', lang))),
        );
      }
      return;
    }

    // 2️⃣ Check delivery zone
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

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add({
            'type': 'others',
            'clientId': user!.uid,
            'clientPhone': _phoneController.text.trim(),
            'fromWhere': _fromWhereController.text.trim(),
            'whatIsIt': _whatIsItController.text.trim(),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'location': GeoPoint(
              widget.position!.latitude,
              widget.position!.longitude,
            ),
            // ⚠️ NO assignedWorkerId here
          });

      if (mounted) {
        // Go back to home screen
        Navigator.pop(context);

        // Show cancelable snackbar for 60 seconds
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 60),
            content: Text(t('order_sent_cancel_hint', lang)),
            action: SnackBarAction(
              label: t('cancel', lang),
              onPressed: () async {
                await _cancelOrder(orderRef.id);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t('error', lang)}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Cancels the order if it's still pending and within 60 seconds.
  Future<void> _cancelOrder(String orderId) async {
    try {
      final orderSnap = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderSnap.exists) return;

      final data = orderSnap.data()!;
      final status = data['status'] as String?;
      if (status != 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t('cancel_too_late', lang))));
        }
        return;
      }

      // Check time difference
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final diff = DateTime.now()
            .toUtc()
            .difference(createdAt.toDate())
            .inSeconds;
        if (diff > 60) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t('cancel_too_late', lang))));
          }
          return;
        }
      }

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': 'cancelled'},
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('order_cancelled', lang))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t('error', lang)}: $e')));
      }
    }
  }

  // Helper to get current language code outside the build method
  String get lang =>
      Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
}
