import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Food', 'Shopping', 'Ride', 'Packages'];

  // Map filters to order type keys
  String _filterToType(String filter) {
    switch (filter) {
      case 'Food':
        return 'food';
      case 'Shopping':
        return 'shop';
      case 'Ride':
        return 'uber';
      case 'Packages':
        return 'transport';
      default:
        return 'all';
    }
  }

  Color _filterColor(String filter) {
    switch (filter) {
      case 'Food':
        return const Color(0xFFFF5724);
      case 'Shopping':
        return const Color(0xFFFFB84D);
      case 'Ride':
        return const Color(0xFFFF8B3D);
      case 'Packages':
        return const Color(0xFF4A4A4A);
      default:
        return const Color(0xFF4A4A4A);
    }
  }

  IconData _filterIcon(String filter) {
    switch (filter) {
      case 'Food':
        return Icons.restaurant;
      case 'Shopping':
        return Icons.shopping_cart;
      case 'Ride':
        return Icons.local_taxi;
      case 'Packages':
        return Icons.local_shipping;
      default:
        return Icons.local_offer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('offers', lang)),
        backgroundColor: const Color(0xFFFF5724),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category filter chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: _filterColor(filter).withOpacity(0.2),
                  checkmarkColor: _filterColor(filter),
                  backgroundColor: Theme.of(context).cardColor,
                  side: BorderSide(
                    color: isSelected
                        ? _filterColor(filter)
                        : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedFilter = filter);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Offers grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('offers')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('${t('error', lang)}: ${snapshot.error}'),
                  );
                }

                final allOffers = snapshot.data?.docs ?? [];

                // Filter by category if not "All"
                final filteredOffers = _selectedFilter == 'All'
                    ? allOffers
                    : allOffers.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final type = data['type'] ?? '';
                        return type == _filterToType(_selectedFilter);
                      }).toList();

                if (filteredOffers.isEmpty) {
                  return Center(child: Text(t('no_offers', lang)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOffers.length,
                  itemBuilder: (context, index) {
                    final offer =
                        filteredOffers[index].data() as Map<String, dynamic>;
                    return _buildOfferCard(offer, lang);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, String lang) {
    final title = offer['title'] ?? '';
    final description = offer['description'] ?? '';
    final discount = offer['discount'] ?? '';
    final expiry = offer['expiryDate'] as Timestamp?;
    final imageUrl = offer['imageUrl'] as String?;
    final type = offer['type'] ?? 'food';
    final terms = offer['terms'] ?? '';

    String _filterToDisplay(String type) {
      switch (type) {
        case 'food':
          return 'Food';
        case 'shop':
          return 'Shopping';
        case 'uber':
          return 'Ride';
        case 'transport':
          return 'Packages';
        default:
          return 'All';
      }
    }

    final color = _filterColor(_filterToDisplay(type));
    final icon = _filterIcon(_filterToDisplay(type));



    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      shadowColor: Colors.black12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with discount badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: color.withOpacity(0.1),
                          child: Icon(icon, size: 48, color: color),
                        ),
                      )
                    : Container(
                        height: 160,
                        color: color.withOpacity(0.1),
                        child: Icon(icon, size: 48, color: color),
                      ),
              ),
              if (discount.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      discount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A4A4A),
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (expiry != null)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${t('expires', lang)} ${_formatDate(expiry.toDate())}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (terms.isNotEmpty)
                      Expanded(
                        child: Text(
                          terms,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to the relevant order screen (or apply action)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${t('offer_applied', lang)}!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(t('apply_offer', lang)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
