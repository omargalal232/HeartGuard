import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/logger_service.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  static const String _tag = 'EmergencyContactScreen';

  Future<void> _addContact() async {
    if (!_formKey.currentState!.validate()) return;

    // Store the context before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create the contact document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergency_contacts')
          .add({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'relation': _relationController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Check if the widget is still mounted before using BuildContext
      if (!mounted) return;
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Contact added successfully')),
      );
      // Clear the form
      _nameController.clear();
      _phoneController.clear();
      _relationController.clear();
    } catch (e) {
      _logger.e(_tag, 'Error adding contact', e);
      
      // Check if the widget is still mounted before using BuildContext
      if (!mounted) return;
      
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error adding contact: $e')),
      );
    }
  }

  Future<void> _deleteContact(DocumentReference reference) async {
    try {
      // Store the context before async operation
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      await reference.delete();
      
      if (!mounted) return;
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Contact deleted successfully')),
      );
    } catch (e) {
      _logger.e(_tag, 'Error deleting contact', e);
      
      if (!mounted) return;
      
      // Store the context to avoid using it after an async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error deleting contact: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
      ),
      body: Column(
        children: [
          // Form for adding new contacts
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a phone number' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _relationController,
                    decoration: const InputDecoration(
                      labelText: 'Relation',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter the relation' : null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addContact,
                    child: const Text('Add Contact'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          // List of existing contacts
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _auth.currentUser != null
                  ? _firestore
                      .collection('users')
                      .doc(_auth.currentUser!.uid)
                      .collection('emergency_contacts')
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = snapshot.data?.docs ?? [];

                if (contacts.isEmpty) {
                  return const Center(
                    child: Text('No emergency contacts added yet'),
                  );
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.contact_phone),
                      title: Text(contact['name'] ?? ''),
                      subtitle: Text(
                          '${contact['phone'] ?? ''}\n${contact['relation'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteContact(contacts[index].reference);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 