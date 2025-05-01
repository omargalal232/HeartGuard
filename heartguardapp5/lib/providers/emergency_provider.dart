import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_contact.dart';
import '../services/logger_service.dart';

class EmergencyProvider with ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  static const String _tag = 'EmergencyProvider';
  
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
          .map((doc) => EmergencyContact.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    } catch (e) {
      _logger.logE(_tag, 'Error loading emergency contacts', e);
    }
  }

  Future<void> addContact(String userId, EmergencyContact contact) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .add(contact.toMap());

      final updatedContact = EmergencyContact.fromMap(contact.toMap(), docRef.id);
      _contacts.add(updatedContact);
      notifyListeners();
    } catch (e) {
      _logger.logE(_tag, 'Error adding emergency contact', e);
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
