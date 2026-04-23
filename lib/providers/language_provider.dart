import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('fr'); // default French
  Locale get locale => _locale;

  // Load saved language from device storage
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language') ?? 'fr';
    _locale = Locale(langCode);
    notifyListeners();
  }

  // Change language and save
  Future<void> setLanguage(String langCode) async {
    _locale = Locale(langCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
  }

  // Helper to get translated strings (simplified for now)
  String translate(String key) {
    // We'll add a basic translation map later
    return key;
  }
}