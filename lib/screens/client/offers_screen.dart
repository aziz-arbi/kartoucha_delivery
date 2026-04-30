import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data?.docs ?? [];

        // Empty state
        if (offers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF8B3D).withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    size: 64,
                    color: Color(0xFFFF8B3D),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aucune offre pour le moment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A4A4A), // Tundora
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Revenez bientôt pour découvrir nos promotions !',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        // List of offers
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index].data() as Map<String, dynamic>;
            return _AnimatedOfferCard(index: index, offer: offer);
          },
        );
      },
    );
  }
}

class _AnimatedOfferCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> offer;

  const _AnimatedOfferCard({required this.index, required this.offer});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 120)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - value)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Card(
                elevation: 6,
                shadowColor: const Color(0xFFFF8B3D).withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Offer image with gradient overlay
                    if (offer['imageUrl'] != null)
                      Stack(
                        children: [
                          Image.network(
                            offer['imageUrl'],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.4),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          // Offer badge
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5724),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Promo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Title & description
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer['title'] ?? 'Offre spéciale',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4A4A), // Tundora
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            offer['description'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
