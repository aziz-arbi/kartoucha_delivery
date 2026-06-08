import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/translations.dart';
import 'package:provider/provider.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('about_agareb', lang)),
        backgroundColor: const Color(0xFFFF5724),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo & title
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5724),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5724).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Agareb Delivery',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF5724),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('tagline', lang),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Description
            _sectionTitle(t('what_is_agareb', lang), context),
            const SizedBox(height: 12),
            Text(
              t('about_description', lang),
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Live payment highlight
            _sectionTitle(t('live_payment_title', lang), context),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF5724).withOpacity(0.1),
                    const Color(0xFFFF8B3D).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF5724).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments, color: const Color(0xFFFF5724)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('live_payment_how', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(t('live_payment_desc', lang)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Coverage: Agareb
            _sectionTitle(t('coverage', lang), context),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: const Color(0xFFFF8B3D)),
                const SizedBox(width: 8),
                Expanded(child: Text(t('coverage_agareb', lang))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.zoom_out_map, color: const Color(0xFFFFB84D)),
                const SizedBox(width: 8),
                Expanded(child: Text(t('coverage_expanding', lang))),
              ],
            ),
            const SizedBox(height: 24),

            // Key features
            _sectionTitle(t('key_features', lang), context),
            const SizedBox(height: 12),
            _featureItem(context, Icons.restaurant, t('feature_food', lang)),
            _featureItem(context, Icons.local_taxi, t('feature_uber', lang)),
            _featureItem(context, Icons.shopping_cart, t('feature_shop', lang)),
            _featureItem(
              context,
              Icons.local_shipping,
              t('feature_transport', lang),
            ),
            _featureItem(context, Icons.more_horiz, t('feature_others', lang)),
            _featureItem(context, Icons.map, t('feature_tracking', lang)),
            _featureItem(context, Icons.chat, t('feature_chat', lang)),
            _featureItem(context, Icons.celebration, t('feature_referral', lang)),
            const SizedBox(height: 24),

            // How it works (live payment steps)
            _sectionTitle(t('how_live_payment_works', lang), context),
            const SizedBox(height: 12),
            _stepItem(
              '1',
              t('live_payment_step1_title', lang),
              t('live_payment_step1_desc', lang),
            ),
            _stepItem(
              '2',
              t('live_payment_step2_title', lang),
              t('live_payment_step2_desc', lang),
            ),
            _stepItem(
              '3',
              t('live_payment_step3_title', lang),
              t('live_payment_step3_desc', lang),
            ),
            _stepItem(
              '4',
              t('live_payment_step4_title', lang),
              t('live_payment_step4_desc', lang),
            ),
            const SizedBox(height: 24),

            // Version
            Divider(color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${t('version', lang)} $_version',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '© 2025 Agareb Delivery',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFF5724),
      ),
    );
  }

  Widget _featureItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFF8B3D)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _stepItem(String stepNumber, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5724),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
