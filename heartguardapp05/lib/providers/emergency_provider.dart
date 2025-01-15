import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_contact.dart';

class EmergencyProvider with ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  List<EmergencyContact> _contacts = [];
  bool _isEmergencyMode = false;

  List<EmergencyContact> get contacts => _contacts;
  bool get isEmergencyMode => _isEmergencyMode;

  Future<void> loadContacts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .get();

      _contacts = snapshot.docs
          .map((doc) => EmergencyContact.fromMap(doc.data()))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading emergency contacts: $e');
    }
  }

  Future<void> addContact(String userId, EmergencyContact contact) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .add(contact.toMap());

      contact.id = docRef.id;
      _contacts.add(contact);
      notifyListeners();
    } catch (e) {
      print('Error adding emergency contact: $e');
    }
  }

  void triggerEmergencyMode() {
    _isEmergencyMode = true;
    notifyListeners();
    // Implement emergency notification logic here
  }

  void cancelEmergencyMode() {
    _isEmergencyMode = false;
    notifyListeners();
  }
} 