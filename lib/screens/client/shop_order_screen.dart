import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';
import '../../utils/operating_hours_utils.dart';
import '../../utils/zone_utils.dart';
import '../../utils/phone_validator.dart';
import '../../utils/delivery_fee_utils.dart'; // ← new import

class ShopOrderScreen extends StatefulWidget {
  final Position? position;
  const ShopOrderScreen({super.key, required this.position});

  @override
  State<ShopOrderScreen> createState() => _ShopOrderScreenState();
}

class _ShopOrderScreenState extends State<ShopOrderScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _shopController = TextEditingController();
  final _orderController = TextEditingController();
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
        title: Text(t('shop', lang)),
        backgroundColor: const Color(0xFFFFB84D), // Texas Rose
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Shop header card
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB84D), Color(0xFFFF8B3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB84D).withOpacity(0.3),
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
                        Icons.shopping_cart,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('shop_heading', lang),
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
                              color: Color(0xFFFF5724), // Orange accent
                            ),
                          ),
                          validator: (v) => PhoneValidator.validate(
                            v,
                            t('required_field', lang),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _shopController,
                          decoration: InputDecoration(
                            labelText: t('specific_shop', lang),
                            prefixIcon: const Icon(
                              Icons.store,
                              color: Color(0xFFFFB84D), // Texas Rose
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _orderController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: t('shopping_list', lang),
                            prefixIcon: const Icon(
                              Icons.list_alt,
                              color: Color(0xFFFFB84D),
                            ),
                          ),
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
                                0xFFFFB84D,
                              ), // Texas Rose
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),

                        // ---------- Delivery fee display ----------
                        const SizedBox(height: 16),
                        const Divider(color: Colors.grey, thickness: 1),
                        const SizedBox(height: 8),
                        if (widget.position != null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: DeliveryFeeUtils.calculateFee(
                              widget.position!.latitude,
                              widget.position!.longitude,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return Text(
                                  '${t('delivery_fee', lang)} : ${t('free', lang)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }
                              final feeInfo = snapshot.data!;
                              final fee = feeInfo['fee'] as double;
                              final summary = feeInfo['summary'] as String;
                              return Column(
                                children: [
                                  Text(
                                    '${t('delivery_fee', lang)} : ${fee.toStringAsFixed(2)} ${t('currency', lang)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A4A4A),
                                    ),
                                  ),
                                ],
                              );
                            },
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

    // 3️⃣ Calculate delivery fee
    double deliveryFee = 0.0;
    String feeSummary = 'Gratuit';
    if (widget.position != null) {
      final feeInfo = await DeliveryFeeUtils.calculateFee(
        widget.position!.latitude,
        widget.position!.longitude,
      );
      deliveryFee = feeInfo['fee'] as double;
      feeSummary = feeInfo['summary'] as String;
    }

    setState(() => _isLoading = true);

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
        // Delivery fee
        'deliveryFee': deliveryFee,
        'feeSummary': feeSummary,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('order_sent', lang))));
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

  String get lang =>
      Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
}
