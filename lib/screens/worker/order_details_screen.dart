import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        _clientLocation = geo != null ? LatLng(geo.latitude, geo.longitude) : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _finishOrder() async {
    setState(() => _isFinishing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final workerDoc = await FirebaseFirestore.instance
          .collection('workers')
          .where('phone', isEqualTo: user!.email?.replaceAll('@kartoucha.com', ''))
          .get();
      final workerDocId = workerDoc.docs.first.id;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
          FirebaseFirestore.instance.collection('orders').doc(widget.orderId),
          {'status': 'completed', 'completedAt': FieldValue.serverTimestamp(), 'assignedWorkerId': FieldValue.delete()},
        );
        transaction.update(
          FirebaseFirestore.instance.collection('workers').doc(workerDocId),
          {'currentOrderId': null},
        );
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isFinishing = false);
    }
  }

  Future<void> _openMaps() async {
    if (_clientLocation == null) return;
    final url =
        'https://www.openstreetmap.org/directions?engine=graphhopper_car&route=;${_clientLocation!.latitude},${_clientLocation!.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Future<void> _callClient() async {
    final phone = _order?['clientPhone'];
    if (phone != null) {
      final url = 'tel:$phone';
      if (await canLaunch(url)) {
        await launch(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Détails commande')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.orderId.substring(0, 6)}')),
      body: Column(
        children: [
          if (_clientLocation != null)
            SizedBox(
              height: 250,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _clientLocation!,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yourcompany.kartoucha',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _clientLocation!,
                        child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Type', _order!['type']),
                  _buildDetailRow('Téléphone', _order!['clientPhone']),
                  if (_order!.containsKey('orderDetails'))
                    _buildDetailRow('Commande', _order!['orderDetails']),
                  if (_order!.containsKey('destination'))
                    _buildDetailRow('Destination', _order!['destination']),
                  if (_order!.containsKey('shop'))
                    _buildDetailRow('Magasin', _order!['shop']),
                  if (_order!.containsKey('whatToTransport'))
                    _buildDetailRow('À transporter', _order!['whatToTransport']),
                  if (_order!.containsKey('whatIsIt'))
                    _buildDetailRow('Description', _order!['whatIsIt']),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openMaps,
                        icon: Icon(Icons.map),
                        label: Text('Itinéraire'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _callClient,
                        icon: Icon(Icons.phone),
                        label: Text('Appeler'),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isFinishing ? null : _finishOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isFinishing
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('TERMINER LA COMMANDE', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}