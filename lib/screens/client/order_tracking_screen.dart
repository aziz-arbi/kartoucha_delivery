import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _worker;
  LatLng? _clientLocation;
  LatLng? _workerLocation;
  MapController? _mapController;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _listenToOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToOrder() {
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists) return;

          final data = snapshot.data() as Map<String, dynamic>;
          final geo = data['location'] as GeoPoint?;
          final workerGeo = data['workerLocation'] as GeoPoint?;

          setState(() {
            _order = data;
            _clientLocation = geo != null
                ? LatLng(geo.latitude, geo.longitude)
                : null;
            _workerLocation = workerGeo != null
                ? LatLng(workerGeo.latitude, workerGeo.longitude)
                : null;
          });

          final workerId = data['assignedWorkerId'] as String?;
          if (workerId != null && _worker == null) {
            final workerSnap = await FirebaseFirestore.instance
                .collection('workers')
                .doc(workerId)
                .get();
            if (workerSnap.exists && mounted) {
              setState(() {
                _worker = workerSnap.data();
              });
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('order_tracking', lang))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = _order!['status'] as String? ?? 'pending';
    final type = _order!['type'] as String? ?? '';
    final statusText = _getStatusText(status, lang);
    final statusColor = _getStatusColor(status);

    return Scaffold(
      appBar: AppBar(
        title: Text('${t('order', lang)} #${widget.orderId.substring(0, 6)}'),
        backgroundColor: const Color(0xFFFF5724),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5724), Color(0xFFFF8B3D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5724).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    _iconForType(type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t('your_order', lang)} ${type.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Map
          if (_clientLocation != null)
            Container(
              height: 250,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _clientLocation!,
                    initialZoom: 14.0,
                  ),
                  mapController: _mapController,
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.yourcompany.kartoucha',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _clientLocation!,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                    if (_workerLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _workerLocation!,
                            child: const Icon(
                              Icons.delivery_dining,
                              color: Colors.blue,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

          // Details card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(t('order_details_title', lang)),
                  _detailCard([
                    _detailRow(t('type', lang), type),
                    _detailRow(t('status', lang), statusText),
                    _detailRow(t('phone', lang), _order!['clientPhone'] ?? ''),
                    if (_order!.containsKey('orderDetails'))
                      _detailRow(
                        t('order_details_label', lang),
                        _order!['orderDetails'],
                      ),
                    if (_order!.containsKey('destination'))
                      _detailRow(
                        t('destination', lang),
                        _order!['destination'],
                      ),
                    if (_order!.containsKey('fromWhere'))
                      _detailRow(t('from_where', lang), _order!['fromWhere']),
                    if (_order!.containsKey('whatIsIt'))
                      _detailRow(t('description', lang), _order!['whatIsIt']),
                  ]),
                  const SizedBox(height: 12),
                  if (_worker != null) ...[
                    _sectionTitle(t('your_delivery_person', lang)),
                    _detailCard([
                      _detailRow(t('name', lang), _worker!['name'] ?? ''),
                      _detailRow(t('phone', lang), _worker!['phone'] ?? ''),
                    ]),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4A4A4A),
        ),
      ),
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF4A4A4A)),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status, String lang) {
    switch (status) {
      case 'pending':
        return t('status_pending', lang);
      case 'approved':
        return t('status_approved', lang);
      case 'assigned':
        return t('status_assigned', lang);
      case 'completed':
        return t('status_completed', lang);
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'assigned':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
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
