import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartguardapp05/services/logger_service.dart';

// Mock classes for Firestore types
class MockCollectionRef extends Mock {
  final CollectionReference<Map<String, dynamic>> collection;
  MockCollectionRef(this.collection);
}

class MockDocRef extends Mock {
  final DocumentReference<Map<String, dynamic>> document;
  MockDocRef(this.document);
}

class MockDocSnap extends Mock {
  final DocumentSnapshot<Map<String, dynamic>> snapshot;
  MockDocSnap(this.snapshot);
}

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  LoggerService,
  User,
  UserCredential,
])
void main() {} 