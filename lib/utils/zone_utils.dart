import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneUtils {
  /// Standard ray‑casting point‑in‑polygon (vertical ray, upward).
  static bool isPointInPolygon(
    double lat,
    double lng,
    List<Map<String, double>> polygon,
  ) {
    bool inside = false;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      // Check if the edge straddles the vertical line at 'lng'
      final bool straddles =
          (p1['lng']! <= lng && p2['lng']! > lng) ||
          (p2['lng']! <= lng && p1['lng']! > lng);

      if (straddles) {
        // Compute the latitude where the edge crosses the vertical line
        final double deltaLng = p2['lng']! - p1['lng']!;
        final double ratio = (lng - p1['lng']!) / deltaLng;
        final double intersectLat =
            p1['lat']! + ratio * (p2['lat']! - p1['lat']!);

        if (intersectLat > lat) {
          inside = !inside;
        }
      }
    }
    return inside;
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

      if (isPointInPolygon(latitude, longitude, polygon)) {
        return true;
      }
    }
    return false;
  }
}
