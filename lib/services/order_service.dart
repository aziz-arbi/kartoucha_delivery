import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class OrderService {
  static Future<void> submitOrder({
    required String type,
    required Position position,
    required Map<String, dynamic> additionalData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    
    await FirebaseFirestore.instance.collection('orders').add({
      'type': type,
      'clientId': user.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'location': GeoPoint(position.latitude, position.longitude),
      ...additionalData,
    });
  }
}