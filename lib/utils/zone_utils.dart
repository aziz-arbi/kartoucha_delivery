import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneUtils {
  /// Ray‑casting point‑in‑polygon algorithm.
  static bool _isPointInPolygon(
    double lat,
    double lng,
    List<Map<String, double>> polygon,
  ) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      if (p1['lng'] == p2['lng']) continue;
      if (lng < (p1['lng']! < p2['lng']! ? p1['lng']! : p2['lng']!)) continue;
      final slope = (p2['lat']! - p1['lat']!) / (p2['lng']! - p1['lng']!);
      final intersectLat = p1['lat']! + slope * (lng - p1['lng']!);
      if (intersectLat > lat) intersectCount++;
    }
    return intersectCount % 2 == 1;
  }

  /// Returns `true` if the given coordinates are inside at least one active zone.
  static Future<bool> isLocationInAnyActiveZone(
    double latitude,
    double longitude,
  ) async {
    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('zones')
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in zonesSnapshot.docs) {
      final data = doc.data();
      final polygonRaw = data['polygon'] as List? ?? [];
      if (polygonRaw.isEmpty) continue;

      // Convert Firestore list of maps to List<Map<String, double>>
      final polygon = polygonRaw.map<Map<String, double>>((p) {
        return {
          'lat': (p['lat'] as num).toDouble(),
          'lng': (p['lng'] as num).toDouble(),
        };
      }).toList();

      if (_isPointInPolygon(latitude, longitude, polygon)) {
        return true;
      }
    }
    return false;
  }
}
