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

class FoodOrderScreen extends StatefulWidget {
  final Position? position;
  const FoodOrderScreen({super.key, required this.position});

  @override
  State<FoodOrderScreen> createState() => _FoodOrderScreenState();
}

class _FoodOrderScreenState extends State<FoodOrderScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  // Restaurant selection
  String? _selectedRestaurantId;
  String? _selectedRestaurantName;

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

  // Check if a restaurant is currently open based on its hours
  bool _isRestaurantOpen(Map<String, dynamic> restaurant) {
    // 1. Check if today is a closed day
    final closedDays = List<int>.from(restaurant['closedDays'] ?? []);
    // DateTime.weekday: Mon=1 … Sun=7. We match admin’s 0=Sun.
    final today = DateTime.now().weekday % 7;
    if (closedDays.contains(today)) return false;

    // 2. If no opening hours are set, the restaurant is always open
    final openStr = restaurant['openTime'] as String? ?? '';
    final closeStr = restaurant['closeTime'] as String? ?? '';
    if (openStr.isEmpty || closeStr.isEmpty) return true;

    try {
      final now = DateTime.now();
      final openParts = openStr.split(':');
      final closeParts = closeStr.split(':');
      DateTime openTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(openParts[0]),
        int.parse(openParts[1]),
      );
      DateTime closeTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(closeParts[0]),
        int.parse(closeParts[1]),
      );

      // Handle overnight hours (e.g. 22:00 – 02:00)
      if (closeTime.isBefore(openTime)) {
        // Move closeTime to the next day
        closeTime = closeTime.add(const Duration(days: 1));
      }

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (_) {
      // If parsing fails, better to show the restaurant than to hide it
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('food', lang)),
        backgroundColor: const Color(0xFFFF5724),
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Food header card
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5724), Color(0xFFFF8B3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5724).withOpacity(0.3),
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
                        Icons.restaurant,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('food_heading', lang),
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
                              color: Color(0xFFFF5724),
                            ),
                          ),
                          validator: (v) => PhoneValidator.validate(
                            v,
                            t('required_field', lang),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ----- Horizontal restaurant list -----
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('restaurants')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final restaurants = snapshot.data!.docs
                                .map(
                                  (doc) => doc.data() as Map<String, dynamic>,
                                )
                                .where((r) => _isRestaurantOpen(r))
                                .toList();

                            if (restaurants.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t('restaurants', lang)} (${t('optional', lang)})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF4A4A4A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 110,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: restaurants.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final r = restaurants[index];
                                      final rName = r['name'] ?? '';
                                      final rLogo = r['logoUrl'] as String?;
                                      final isSelected =
                                          _selectedRestaurantId ==
                                          snapshot.data!.docs[index].id;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedRestaurantId =
                                                snapshot.data!.docs[index].id;
                                            _selectedRestaurantName = rName;
                                          });
                                        },
                                        child: Container(
                                          width: 90,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color.fromARGB(255, 250, 71, 0)
                                                  : Colors.grey.shade300,
                                              width: isSelected ? 2 : 1,
                                            ),
                                            color: isSelected
                                                ? const Color(
                                                    0xFFFF5724,
                                                  ).withValues(alpha: 0.1)
                                                : const Color.fromARGB(255, 250, 71, 0),
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                child: rLogo != null
                                                    ? Image.network(
                                                        rLogo,
                                                        height: 48,
                                                        width: 48,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              __,
                                                              ___,
                                                            ) => const Icon(
                                                              Icons.restaurant,
                                                              size: 36,
                                                              color: Color(
                                                                0xFFFF5724,
                                                              ),
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.restaurant,
                                                        size: 36,
                                                        color: Color(
                                                          0xFFFF5724,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                rName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: const Color(
                                                    0xFF4A4A4A,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _orderController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: t('order_details_label', lang),
                            prefixIcon: const Icon(
                              Icons.list_alt,
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
                              backgroundColor: const Color(0xFFFF5724),
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
                                      color: Color.fromARGB(255, 255, 102, 0),
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
        'type': 'food',
        'clientId': user!.uid,
        'clientPhone': _phoneController.text.trim(),
        'orderDetails': _orderController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'location': GeoPoint(
          widget.position!.latitude,
          widget.position!.longitude,
        ),
        // Restaurant info (optional)
        if (_selectedRestaurantId != null)
          'restaurantId': _selectedRestaurantId,
        if (_selectedRestaurantName != null)
          'restaurantName': _selectedRestaurantName,
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
