// Similar to food, but with an extra 'shop' field
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ShopOrderScreen extends StatefulWidget {
  final Position? position;
  const ShopOrderScreen({super.key, required this.position});

  @override
  State<ShopOrderScreen> createState() => _ShopOrderScreenState();
}

class _ShopOrderScreenState extends State<ShopOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _shopController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande Shop')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _phoneController, decoration: InputDecoration(labelText: 'Téléphone')),
              TextFormField(controller: _shopController, decoration: InputDecoration(labelText: 'Magasin spécifique')),
              TextFormField(controller: _orderController, maxLines: 3, decoration: InputDecoration(labelText: 'Liste de courses')),
              SizedBox(height: 24),
              ElevatedButton(onPressed: _submitOrder, child: Text('Confirmer')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    // similar submission logic, include 'shop' field
  }
}