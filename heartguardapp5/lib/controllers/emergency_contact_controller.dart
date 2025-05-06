import 'package:heartguardapp05/services/firestore_service.dart';
import 'package:heartguardapp05/services/logger_service.dart';

class EmergencyContactController {
  final FirestoreService _firestoreService;
  final LoggerService _logger;

  EmergencyContactController({
    required FirestoreService firestoreService,
    required LoggerService logger,
  })  : _firestoreService = firestoreService,
        _logger = logger;

  Future<void> addContact(Map<String, dynamic> contact) async {
    try {
      await _firestoreService.addDocument('emergency_contacts', contact);
      _logger.i('Emergency contact added successfully');
    } catch (e) {
      _logger.e('Error adding emergency contact: $e');
      rethrow;
    }
  }

  Future<void> updateContact(
    String contactId,
    Map<String, dynamic> contact,
  ) async {
    try {
      await _firestoreService.updateDocument(
        'emergency_contacts',
        contactId,
        contact,
      );
      _logger.i('Emergency contact updated successfully: $contactId');
    } catch (e) {
      _logger.e('Error updating emergency contact: $e');
      rethrow;
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _firestoreService.deleteDocument('emergency_contacts', contactId);
      _logger.i('Emergency contact deleted successfully: $contactId');
    } catch (e) {
      _logger.e('Error deleting emergency contact: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getContact(String contactId) async {
    try {
      final contact = await _firestoreService.getDocument(
        'emergency_contacts',
        contactId,
      );
      if (contact == null) {
        _logger.w('Emergency contact not found: $contactId');
      } else {
        _logger.i('Emergency contact retrieved successfully: $contactId');
      }
      return contact;
    } catch (e) {
      _logger.e('Error getting emergency contact: $e');
      rethrow;
    }
  }
} 