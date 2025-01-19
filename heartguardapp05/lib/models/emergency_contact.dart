class EmergencyContact {
  final String? id;
  final String name;
  final String phone;
  final String relation;

  EmergencyContact({
    this.id,
    required this.name,
    required this.phone,
    required this.relation,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyContact(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relation: map['relation'] ?? '',
    );
  }
} 