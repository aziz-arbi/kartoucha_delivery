import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  /// Returns `true` if the app must be updated (current version < required version).
  static Future<bool> isUpdateRequired() async {
    try {
      // Fetch the minimum required version from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app')
          .get();

      if (!doc.exists) return false; // no version set → no restriction

      final data = doc.data()!;
      final requiredVersion = data['minVersion'] as String? ?? '0.0.0';
      final updateUrl =
          data['updateUrl'] as String? ??
          'https://play.google.com/store/apps/details?id=com.yourcompany.kartoucha';

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Compare versions (you can use a proper comparison like `package:version`)
      return _compareVersions(currentVersion, requiredVersion) < 0;
    } catch (e) {
      print('Error checking update: $e');
      return false; // fail open – don't block the user on network errors
    }
  }

  /// Returns the update URL stored in Firestore (or a fallback).
  static Future<String> getUpdateUrl() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app')
          .get();
      return doc.data()?['updateUrl'] as String? ??
          'https://play.google.com/store/apps/details?id=com.yourcompany.kartoucha';
    } catch (_) {
      return 'https://play.google.com/store/apps/details?id=com.yourcompany.kartoucha';
    }
  }

  /// Simple version comparison (1.0.0 vs 1.0.1 etc.)
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final aPart = i < aParts.length ? aParts[i] : 0;
      final bPart = i < bParts.length ? bParts[i] : 0;
      if (aPart < bPart) return -1;
      if (aPart > bPart) return 1;
    }
    return 0;
  }
}
