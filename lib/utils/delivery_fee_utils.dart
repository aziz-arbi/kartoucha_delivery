import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class DeliveryFeeUtils {
  static Future<Map<String, dynamic>> calculateFee(
    double clientLat,
    double clientLng,
  ) async {
    final doc = await FirebaseFirestore.instance
        .doc('settings/delivery_fee')
        .get();
    if (!doc.exists) {
      return {'fee': 0.0, 'summary': 'Gratuit'};
    }
    final data = doc.data()!;
    final centerMap = data['center'] as Map<String, dynamic>?;
    if (centerMap == null) {
      return {'fee': 0.0, 'summary': 'Gratuit (aucun point central)'};
    }
    final center = LatLng(
      (centerMap['lat'] as num).toDouble(),
      (centerMap['lng'] as num).toDouble(),
    );

    final distance = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(clientLat, clientLng),
      center,
    );

    final radius1 = (data['radius1'] as num?)?.toDouble() ?? 3;
    final radius2 = (data['radius2'] as num?)?.toDouble() ?? 6;
    final radius3 = (data['radius3'] as num?)?.toDouble() ?? 10;
    final fee1 = (data['fee1'] as num?)?.toDouble() ?? 2.2;
    final fee2 = (data['fee2'] as num?)?.toDouble() ?? 3.5;
    final fee3 = (data['fee3'] as num?)?.toDouble() ?? 5.5;

    double fee;
    String summary;
    if (distance <= radius1) {
      fee = fee1;
      summary =
          'Petite zone (≤ ${radius1.toStringAsFixed(0)} km) : ${fee.toStringAsFixed(2)} TND';
    } else if (distance <= radius2) {
      fee = fee2;
      summary =
          'Moyenne zone (≤ ${radius2.toStringAsFixed(0)} km) : ${fee.toStringAsFixed(2)} TND';
    } else if (distance <= radius3) {
      fee = fee3;
      summary =
          'Grande zone (≤ ${radius3.toStringAsFixed(0)} km) : ${fee.toStringAsFixed(2)} TND';
    } else {
      // Outside all zones – apply largest fee (you can change this to block orders)
      fee = fee3;
      summary =
          'Hors zone (${distance.toStringAsFixed(1)} km) – ${fee.toStringAsFixed(2)} TND';
    }

    return {
      'fee': fee,
      'summary': '$summary (${distance.toStringAsFixed(1)} km)',
    };
  }
}
