import 'package:flutter/foundation.dart';

class EmergencyProvider with ChangeNotifier {
  final List<String> _emergencyContacts = [];

  // Getter for emergency contacts
  List<String> get emergencyContacts => List.unmodifiable(_emergencyContacts);

  // Add a contact
  void addContact(String contact) {
    if (!_emergencyContacts.contains(contact)) {
      _emergencyContacts.add(contact);
      notifyListeners();
    }
  }

  // Update a contact
  void updateContact(String oldContact, String newContact) {
    final index = _emergencyContacts.indexOf(oldContact);
    if (index != -1) {
      _emergencyContacts[index] = newContact;
      notifyListeners();
    }
  }

  // Remove a contact
  void removeContact(String contact) {
    if (_emergencyContacts.remove(contact)) {
      notifyListeners();
    }
  }

  // Clear all contacts
  void clearContacts() {
    _emergencyContacts.clear();
    notifyListeners();
  }
} 