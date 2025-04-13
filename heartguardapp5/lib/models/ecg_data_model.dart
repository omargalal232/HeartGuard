import 'package:cloud_firestore/cloud_firestore.dart';

class ECGDataModel {
  final String id;
  final DateTime timestamp;
  final List<double> rawData;
  final Map<String, dynamic> features;
  final Map<String, dynamic>? analysis;
  final bool hasAnomaly;

  ECGDataModel({
    required this.id,
    required this.timestamp,
    required this.rawData,
    required this.features,
    this.analysis,
    required this.hasAnomaly,
  });

  factory ECGDataModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ECGDataModel(
      id: id ?? json['id'] ?? '',
      timestamp: json['timestamp'] is Timestamp 
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.parse(json['timestamp'].toString()),
      rawData: (json['rawData'] as List<dynamic>?)?.map((e) => e as double).toList() ?? [],
      features: json['features'] as Map<String, dynamic>? ?? {},
      analysis: json['analysis'] as Map<String, dynamic>?,
      hasAnomaly: json['hasAnomaly'] as bool? ?? false,
    );
  }

  factory ECGDataModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data was null');
    }
    
    return ECGDataModel.fromJson(data, id: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'rawData': rawData,
      'features': features,
      'analysis': analysis,
      'hasAnomaly': hasAnomaly,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': FieldValue.serverTimestamp(),
      'rawData': rawData,
      'features': features,
      'analysis': analysis,
      'hasAnomaly': hasAnomaly,
    };
  }
} 