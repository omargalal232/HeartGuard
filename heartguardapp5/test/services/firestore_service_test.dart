import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartguardapp05/services/firestore_service.dart';
import 'package:heartguardapp05/models/profile_model.dart';
import '../test_helper.mocks.dart';

void main() {
  late FirestoreService firestoreService;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockLoggerService mockLogger;
  late MockUser mockUser;


  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockLogger = MockLoggerService();
    mockUser = MockUser();
 
    
    firestoreService = FirestoreService(
      firestore: mockFirestore,
      auth: mockAuth,
      logger: mockLogger,
    );

    // Setup common mock behaviors
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-user-id');
 
  });

  group('createProfile', () {
    test('should create profile successfully when user is authenticated', () async {
      // Arrange
      final profile = ProfileModel(
        uid: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        phoneNumber: '+1234567890',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        height: 175,
        weight: 70,
        bloodType: 'A+',
        medicalConditions: ['None'],
        medications: ['None'],
        allergies: ['None'],
        emergencyContacts: [],
      );

   

      // Act
      await firestoreService.createProfile(profile);

      // Assert
      verify(mockFirestore.collection('profiles')).called(1);
      verify(mockLogger.i(any)).called(1);
      verifyNever(mockLogger.e(any));
    });

    test('should throw exception when user is not authenticated', () async {
      // Arrange
      when(mockAuth.currentUser).thenReturn(null);
      final profile = ProfileModel(
        uid: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        phoneNumber: '',
        dateOfBirth: DateTime.now(),
        gender: 'Not specified',
        height: 0,
        weight: 0,
        bloodType: 'Unknown',
        medicalConditions: [],
        medications: [],
        allergies: [],
        emergencyContacts: [],
      );

      // Act & Assert
      expect(
        () => firestoreService.createProfile(profile),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('getProfile', () {
    test('should return profile when it exists', () async {
      // Arrange
    

  

      // Act
      final result = await firestoreService.getProfile('test-user-id');

      // Assert
      expect(result, isNotNull);
      expect(result!.uid, equals('test-user-id'));
      verify(mockFirestore.collection('profiles')).called(1);
      verify(mockLogger.i(any)).called(1);
    });

    test('should return null when profile does not exist', () async {
      // Arrange


      // Act
      final result = await firestoreService.getProfile('test-user-id');

      // Assert
      expect(result, isNull);
      verify(mockFirestore.collection('profiles')).called(1);
      verify(mockLogger.i(any)).called(1);
    });
  });

  group('updateProfile', () {
    test('should update profile successfully', () async {
      // Arrange
     


      final profile = ProfileModel(
        uid: 'test-user-id',
        email: 'test@example.com',
        name: 'Updated Name',
        phoneNumber: '',
        dateOfBirth: DateTime.now(),
        gender: 'Not specified',
        height: 0,
        weight: 0,
        bloodType: 'Unknown',
        medicalConditions: [],
        medications: [],
        allergies: [],
        emergencyContacts: [],
      );

      // Act
      await firestoreService.updateProfile(profile);

      // Assert
      verify(mockFirestore.collection('profiles')).called(1);
      verify(mockLogger.i(any)).called(1);
    });
  });
} 