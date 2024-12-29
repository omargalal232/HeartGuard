class EmergencyContactModel {
  final String id; // Firestore auto-generated ID
  final String name;
  final String phoneNumber;
  final String relationship;

  EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
  });

  factory EmergencyContactModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EmergencyContactModel(
      id: documentId,
      name: map['name'],
      phoneNumber: map['phoneNumber'],
      relationship: map['relationship'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
    };
  }
}