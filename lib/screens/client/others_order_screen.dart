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

class _OthersOrderScreenState extends State<OthersOrderScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fromWhereController = TextEditingController();
  final _whatIsItController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('others', lang)),
        backgroundColor: const Color(0xFFD33131), // Persian Red
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header card
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD33131), Color(0xFFFF8B3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD33131).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('others_heading', lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: t('phone', lang),
                            prefixIcon: const Icon(
                              Icons.phone,
                              color: Color(0xFFFF5724), // Orange
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? t('required_field', lang) : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _fromWhereController,
                          decoration: InputDecoration(
                            labelText: t('from_where', lang),
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFFFF5724),
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? t('required_field', lang) : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _whatIsItController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: t('what_is_this', lang),
                            prefixIcon: const Icon(
                              Icons.help_outline,
                              color: Color(0xFFFF5724),
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? t('required_field', lang) : null,
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitOrder,
                            icon: const Icon(Icons.send_rounded),
                            label: Text(
                              t('confirm_order', lang),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFFD33131,
                              ), // Persian Red
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
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
        Navigator.pop(context);
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

  String get lang =>
      Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
}
