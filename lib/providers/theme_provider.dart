import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Load saved preference
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme_mode') ?? 2; // default system
    _mode = AppThemeMode.values[index];
    notifyListeners();
  }

  /// Change theme and persist
  Future<void> setTheme(AppThemeMode newMode) async {
    _mode = newMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', newMode.index);
  }
}
