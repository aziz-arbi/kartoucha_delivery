import 'package:cloud_firestore/cloud_firestore.dart';

class OperatingHoursUtils {
  /// Returns `true` if the service is currently closed.
  static Future<bool> isServiceClosed() async {
    final doc = await FirebaseFirestore.instance
        .doc('settings/operating_hours')
        .get();
    if (!doc.exists) return false; // assume open if no settings

    final data = doc.data()!;
    final now = DateTime.now().toUtc();

    // Check recurring day
    final recurringDays = List<int>.from(data['recurringClosedDays'] ?? []);
    if (recurringDays.contains(now.weekday % 7)) {
      return true;
    }

    // Check exceptions
    final exceptions = List<Map<String, dynamic>>.from(
      data['exceptions'] ?? [],
    );
    for (final ex in exceptions) {
      final start = (ex['start'] as Timestamp).toDate();
      final end = (ex['end'] as Timestamp).toDate();
      if (now.isAfter(start) && now.isBefore(end)) {
        return true;
      }
    }

    return false;
  }
}
