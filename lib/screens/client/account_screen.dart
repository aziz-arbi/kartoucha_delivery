import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/translations.dart';
import '../../services/auth_service.dart';
import 'client_order_history.dart';
import 'notifications_screen.dart';
import 'saved_addresses_screen.dart';
import 'referral_screen.dart';
import 'chat_screen.dart';
import 'live_payment_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    final userNameFuture = user != null
        ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
        : null;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Profile header
          FutureBuilder<DocumentSnapshot?>(
            future: userNameFuture,
            builder: (context, snapshot) {
              String name = '';
              String phone =
                  user?.email?.replaceAll('@kartoucha.com', '') ?? '';
              if (snapshot.hasData && snapshot.data != null) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                name = data?['name'] ?? '';
              }
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF5724), Color(0xFFFF8B3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.isNotEmpty ? name : '3jeja User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone.isNotEmpty ? '+216 $phone' : '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Edit profile (could be a future update)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('coming_soon', lang))),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(t('edit_profile', lang)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Menu items
          _menuItem(context, Icons.shopping_bag, t('my_orders', lang), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientOrderHistory()),
            );
          }),
          _menuItem(context, Icons.location_on, t('saved_addresses', lang), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
            );
          }),
          _menuItem(context, Icons.favorite_border, t('favorites', lang), () {
            // TODO: Favorites screen
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t('coming_soon', lang))));
          }),
          _menuItem(
            context,
            Icons.notifications_outlined,
            t('notifications', lang),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          _menuItem(
            context,
            Icons.language,
            t('change_language', lang),
            null,
            trailing: DropdownButton<String>(
              value: Provider.of<LanguageProvider>(context).locale.languageCode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ar', child: Text('Tounsi')),
              ],
              onChanged: (value) {
                if (value != null)
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).setLanguage(value);
              },
            ),
          ),
          _menuItem(
            context,
            Icons.dark_mode,
            t('theme', lang),
            null,
            trailing: DropdownButton<String>(
              value: _themeModeToKey(themeProvider.mode),
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: 'light', child: Text(t('light', lang))),
                DropdownMenuItem(value: 'dark', child: Text(t('dark', lang))),
                DropdownMenuItem(
                  value: 'system',
                  child: Text(t('system_default', lang)),
                ),
              ],
              onChanged: (value) {
                if (value != null)
                  themeProvider.setTheme(_keyToThemeMode(value));
              },
            ),
          ),
          _menuItem(context, Icons.help_outline, t('help_center', lang), () {
            // TODO: Help Center / FAQ
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t('coming_soon', lang))));
          }),
          _menuItem(context, Icons.headset_mic, t('contact_support', lang), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientChatScreen()),
            );
          }),
          _menuItem(context, Icons.info_outline, t('about_3jeja', lang), () {
            showAboutDialog(
              context: context,
              applicationName: '3jeja',
              applicationVersion: '1.0.0',
              children: [
                const Text('3jeja Delivery – Fast • Reliable • Everywhere'),
              ],
            );
          }),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout),
              label: Text(t('logout', lang)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback? onTap, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  String _themeModeToKey(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }

  AppThemeMode _keyToThemeMode(String key) {
    switch (key) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }
}
