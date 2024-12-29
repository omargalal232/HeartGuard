import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/emergency_contact_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';


class AddEmergencyContactScreen extends StatefulWidget {
  const AddEmergencyContactScreen({super.key});

  @override
  State<AddEmergencyContactScreen> createState() => _AddEmergencyContactScreenState();
}

class _AddEmergencyContactScreenState extends State<AddEmergencyContactScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController relationshipController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  void _addContact() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      setState(() {
        errorMessage = 'User not authenticated';
        isLoading = false;
      });
      return;
    }

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final relationship = relationshipController.text.trim();

    if (name.isEmpty || phone.isEmpty || relationship.isEmpty) {
      setState(() {
        errorMessage = 'All fields are required';
        isLoading = false;
      });
      return;
    }

    final contact = EmergencyContactModel(
      id: '', // Firestore will auto-generate
      name: name,
      phoneNumber: phone,
      relationship: relationship,
    );

    try {
      await firestoreService.addEmergencyContact(userId, contact);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage!)),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Emergency Contact'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: relationshipController,
              decoration: const InputDecoration(labelText: 'Relationship'),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _addContact,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Add Contact'),
            ),
            TextButton(
              onPressed: () {
                nameController.clear();
                phoneController.clear();
                relationshipController.clear();
                setState(() {
                  errorMessage = null;
                });
              },
              child: const Text('Clear Fields'),
            ),
          ],
        ),
      ),
    );
  }
} 