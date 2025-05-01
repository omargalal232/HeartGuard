import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_contact.dart';

class EmergencyContactController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's emergency contacts
  Stream<List<EmergencyContact>> getEmergencyContacts() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('emergencyContacts')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EmergencyContact.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Add new emergency contact
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('emergencyContacts')
        .add(contact.toMap());
  }

  // Delete emergency contact
  Future<void> deleteEmergencyContact(String contactId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('emergencyContacts')
        .doc(contactId)
        .delete();
  }

  // Update emergency contact
  Future<void> updateEmergencyContact(
      String contactId, EmergencyContact contact) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('emergencyContacts')
        .doc(contactId)
        .update(contact.toMap());
  }
} 