import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? _order;
  LatLng? _clientLocation;
  bool _isLoading = true;
  bool _isFinishing = false;

  // ---- Worker tracking & route ----
  StreamSubscription<Position>? _positionStream;
  LatLng? _workerPosition;
  List<LatLng> _routePoints = [];
  Timer? _refreshTimer;
  MapController? _mapController;

  // ---- Full screen map toggle ----
  bool _isFullScreenMap = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      final geo = data['location'] as GeoPoint?;
      setState(() {
        _order = data;
        _clientLocation = geo != null
            ? LatLng(geo.latitude, geo.longitude)
            : null;
        _isLoading = false;
      });
      _startTracking();
    }
  }

  // ---------- Worker tracking & routing ----------
  void _startTracking() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        // ok
      } else {
        return;
      }
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            timeLimit: Duration(minutes: 1),
          ),
        ).listen((Position pos) {
          setState(() {
            _workerPosition = LatLng(pos.latitude, pos.longitude);
          });
          _fetchRoute();
        });

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _fetchRoute();
    });

    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_workerPosition == null || _clientLocation == null) return;

    final start = _workerPosition!;
    final end = _clientLocation!;

    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final geometry = route['geometry']['coordinates'] as List;

        final points = geometry.map((coord) {
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();

        setState(() {
          _routePoints = points;
        });

        if (_mapController != null) {
          final bounds = LatLngBounds.fromPoints([
            _workerPosition!,
            _clientLocation!,
          ]);
          _mapController!.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        }
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
    }
  }

  // ---------- Finish & Release ----------
  Future<void> _finishOrder() async {
    setState(() => _isFinishing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final workerDoc = await FirebaseFirestore.instance
          .collection('workers')
          .where(
            'phone',
            isEqualTo: user!.email?.replaceAll('@kartoucha.com', ''),
          )
          .get();
      final workerDocId = workerDoc.docs.first.id;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
          FirebaseFirestore.instance.collection('orders').doc(widget.orderId),
          {
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'assignedWorkerId': FieldValue.delete(),
          },
        );
        transaction.update(
          FirebaseFirestore.instance.collection('workers').doc(workerDocId),
          {'currentOrderId': null},
        );
      });

      _stopTracking();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t('error', _lang())}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  Future<void> _releaseOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final workerDoc = await FirebaseFirestore.instance
          .collection('workers')
          .where(
            'phone',
            isEqualTo: user!.email?.replaceAll('@kartoucha.com', ''),
          )
          .get();
      final workerDocId = workerDoc.docs.first.id;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
          FirebaseFirestore.instance.collection('orders').doc(widget.orderId),
          {'status': 'approved', 'assignedWorkerId': FieldValue.delete()},
        );
        transaction.update(
          FirebaseFirestore.instance.collection('workers').doc(workerDocId),
          {'currentOrderId': null},
        );
      });
      _stopTracking();
    } catch (e) {
      debugPrint('Release order error: $e');
    }
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _refreshTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTracking();
    _mapController?.dispose();
    super.dispose();
  }

  // ---------- Back navigation with confirmation ----------
  Future<bool> _onWillPop() async {
    final lang = _lang();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('quit_without_finishing', lang)),
        content: Text(t('quit_release_message', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('stay', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('leave_and_release', lang)),
          ),
        ],
      ),
    );
    if (result == true) {
      await _releaseOrder();
      return true;
    }
    return false;
  }

  // ---------- Toggle full screen map ----------
  void _openMaps() {
    setState(() {
      _isFullScreenMap = true;
    });
  }

  // ---------- Call client ----------
  Future<void> _callClient() async {
    final phone = _order?['clientPhone'];
    if (phone != null) {
      final url = 'tel:$phone';
      if (await canLaunch(url)) {
        await launch(url);
      }
    }
  }

  String _lang() {
    return Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;
  }

  // ---------- Shared map widget ----------
  Widget _buildMap() {
    if (_clientLocation == null) return const SizedBox.shrink();
    return FlutterMap(
      options: MapOptions(initialCenter: _clientLocation!, initialZoom: 15.0),
      mapController: _mapController,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yourcompany.kartoucha',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _clientLocation!,
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          ],
        ),
        if (_workerPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _workerPosition!,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
            ],
          ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: Colors.blue,
                strokeWidth: 4,
              ),
            ],
          ),
      ],
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(t('order_details', lang))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Full‑screen map view
    if (_isFullScreenMap) {
      return Scaffold(
        appBar: AppBar(
          title: Text(t('navigation', lang)),
          leading: IconButton(
            icon: const Icon(Icons.close_fullscreen),
            onPressed: () => setState(() => _isFullScreenMap = false),
          ),
        ),
        body: _buildMap(),
      );
    }

    // Normal split view
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${t('order', lang)} #${widget.orderId.substring(0, 6)}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Normal map (small)
            SizedBox(height: 400, child: _buildMap()),
            // Order details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(t('type', lang), _order!['type']),
                    _buildDetailRow(t('phone', lang), _order!['clientPhone']),
                    if (_order!.containsKey('orderDetails'))
                      _buildDetailRow(
                        t('order_details_label', lang),
                        _order!['orderDetails'],
                      ),
                    if (_order!.containsKey('destination'))
                      _buildDetailRow(
                        t('destination', lang),
                        _order!['destination'],
                      ),
                    if (_order!.containsKey('shop'))
                      _buildDetailRow(t('shop', lang), _order!['shop']),
                    if (_order!.containsKey('whatToTransport'))
                      _buildDetailRow(
                        t('what_to_transport', lang),
                        _order!['whatToTransport'],
                      ),
                    if (_order!.containsKey('whatIsIt'))
                      _buildDetailRow(
                        t('description', lang),
                        _order!['whatIsIt'],
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openMaps,
                          icon: const Icon(Icons.map),
                          label: Text(t('navigation', lang)),
                        ),
                        ElevatedButton.icon(
                          onPressed: _callClient,
                          icon: const Icon(Icons.phone),
                          label: Text(t('call', lang)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isFinishing ? null : _finishOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isFinishing
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                t('complete_order', lang),
                                style: const TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
