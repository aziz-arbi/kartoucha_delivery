import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/translations.dart';

class WorkerApplicationScreen extends StatefulWidget {
  const WorkerApplicationScreen({super.key});

  @override
  State<WorkerApplicationScreen> createState() =>
      _WorkerApplicationScreenState();
}

class _WorkerApplicationScreenState extends State<WorkerApplicationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _vehicleType = 'Moto';

  // ✅ CORRECTED: mutable list of selected specialties
  List<String> _selectedSpecialties = ['food'];

  // ✅ CORRECTED: all available specialties (immutable)
  final List<String> _availableSpecialties = [
    'food',
    'shop',
    'uber',
    'transport',
    'others',
  ];

  bool _isSubmitting = false;
  bool _isSubmitted = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  final List<String> _vehicleTypes = ['Moto', 'Voiture', 'Pick-up', 'Camion'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    // Pre-fill phone number from current user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final phone = user.email?.replaceAll('@kartoucha.com', '');
      if (phone != null) _phoneController.text = phone;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('worker_applications').add({
        'name': _nameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicleType': _vehicleType,
        // ✅ CORRECTED: store the selected list, not a single string
        'specialties': _selectedSpecialties,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _isSubmitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('apply_worker', lang)),
        backgroundColor: const Color(0xFFFF8B3D),
      ),
      body: _isSubmitted
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Color(0xFFFF8B3D),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t('application_sent', lang),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : ScaleTransition(
              scale: _scaleAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8B3D), Color(0xFFFFB84D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8B3D).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_alt,
                            size: 50,
                            color: Colors.white,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Rejoignez notre équipe',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Form
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: t('first_name', lang),
                                  prefixIcon: const Icon(
                                    Icons.person,
                                    color: Color(0xFFFF5724),
                                  ),
                                ),
                                validator: (v) => v!.isEmpty
                                    ? t('required_field', lang)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText: t('last_name', lang),
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFFFF5724),
                                  ),
                                ),
                                validator: (v) => v!.isEmpty
                                    ? t('required_field', lang)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: t('phone', lang),
                                  prefixIcon: const Icon(
                                    Icons.phone,
                                    color: Color(0xFFFF5724),
                                  ),
                                ),
                                validator: (v) => v!.isEmpty
                                    ? t('required_field', lang)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              // Vehicle type dropdown
                              DropdownButtonFormField<String>(
                                value: _vehicleType,
                                decoration: InputDecoration(
                                  labelText: t('vehicle_type', lang),
                                  prefixIcon: const Icon(
                                    Icons.directions_car,
                                    color: Color(0xFFFF8B3D),
                                  ),
                                ),
                                items: _vehicleTypes
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _vehicleType = v!),
                              ),
                              const SizedBox(height: 16),
                              // Specialty multi‑select
                              Text(
                                t('specialty', lang),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _availableSpecialties.map((s) {
                                  // ✅ CORRECTED: use _selectedSpecialties & _availableSpecialties
                                  final selected = _selectedSpecialties
                                      .contains(s);
                                  return FilterChip(
                                    label: Text(s.toUpperCase()),
                                    selected: selected,
                                    selectedColor: const Color(
                                      0xFFFFB84D,
                                    ).withValues(alpha: 0.3),
                                    checkmarkColor: const Color(0xFFFF8B3D),
                                    onSelected: (isSelected) {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedSpecialties.add(s);
                                        } else {
                                          _selectedSpecialties.remove(s);
                                        }
                                        if (_selectedSpecialties.isEmpty)
                                          _selectedSpecialties.add('food');
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : _submit,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                  label: Text(
                                    t('submit_application', lang),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF8B3D),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
