import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/profile_model.dart';
import '../models/ecg_reading.dart';
import '../services/ecg_service.dart'; // Add ECGService
import '../services/heart_disease_prediction_service.dart'; // Add heart disease prediction

class MedicalRecordPage extends StatefulWidget {
  static const String routeName = '/medical-record';

  final ProfileModel patientProfile;
  final EcgReading ecgReading;

  const MedicalRecordPage({
    super.key,
    required this.patientProfile,
    required this.ecgReading,
  });

  @override
  State<MedicalRecordPage> createState() => _MedicalRecordPageState();
}

class _MedicalRecordPageState extends State<MedicalRecordPage> {
  Map<String, dynamic>? _analysisResults;
  Map<String, dynamic>? _heartDiseaseRiskResults;
  bool _isAnalyzing = false;
  bool _isPredicting = false;
  String? _analysisError;
  final GlobalKey _screenShotKey = GlobalKey();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _analyzeEcgReading();
    _predictHeartDiseaseRisk();
  }

  Future<void> _analyzeEcgReading() async {
    if (!widget.ecgReading.hasValidData) {
      setState(() {
        _analysisError = 'This ECG reading does not contain valid data for analysis.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final ecgService = ECGService();
      final results = await ecgService.analyzeECGReading(widget.ecgReading);

      setState(() {
        _analysisResults = results;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _analysisError = 'Error analyzing ECG: $e';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _predictHeartDiseaseRisk() async {
    setState(() {
      _isPredicting = true;
    });

    try {
      final predictionService = HeartDiseasePredictionService();
      final results = await predictionService.predictHeartDiseaseRisk(
        widget.patientProfile, 
        widget.ecgReading
      );

      setState(() {
        _heartDiseaseRiskResults = results;
        _isPredicting = false;
      });
    } catch (e) {
      setState(() {
        _isPredicting = false;
      });
    }
  }

  Future<void> _exportMedicalRecord() async {
    try {
      setState(() {
        _exporting = true;
      });
      
      // Capture the screen as an image
      RenderRepaintBoundary boundary = _screenShotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Get documents directory
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final patientName = widget.patientProfile.name.replaceAll(' ', '_');
        final filePath = '${directory.path}/ecg_${patientName}_$timestamp.png';
        
        // Save the image to a file
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);
        
        // Show success message
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medical record saved to:\n$filePath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting medical record: $e')),
      );
    } finally {
      setState(() {
        _exporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Record'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          _exporting
              ? const Center(
                  child: SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share Medical Record',
                  onPressed: _exportMedicalRecord,
                ),
        ],
      ),
      body: RepaintBoundary(
        key: _screenShotKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildPatientInfoSection(),
              const SizedBox(height: 24),
              _buildEcgReadingDetailsSection(),
              const SizedBox(height: 24),
              _buildHeartDiseaseRiskSection(),
              const SizedBox(height: 24),
              _buildAnalysisSection(),
              const SizedBox(height: 24),
              _buildMedicalHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty || value == '0' || value == 'Not specified' || value == 'Unknown') {
      return const SizedBox.shrink(); // Don't display if value is not meaningful
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPatientInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionTitle('Patient Information'),
            _buildInfoRow('Name', widget.patientProfile.name),
            _buildInfoRow('Email', widget.patientProfile.email),
            _buildInfoRow('Phone', widget.patientProfile.phoneNumber),
            _buildInfoRow('Gender', widget.patientProfile.gender),
            _buildInfoRow('Blood Type', widget.patientProfile.bloodType),
          ],
        ),
      ),
    );
  }

  Widget _buildEcgReadingDetailsSection() {
    final ecgDateTime = widget.ecgReading.dateTime;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionTitle('ECG Reading Details'),
            if (ecgDateTime != null)
              _buildInfoRow('Date & Time', DateFormat('yMMMMd H:mm:s').format(ecgDateTime)),
            if (widget.ecgReading.bpm != null)
              _buildInfoRow('Heart Rate', '${widget.ecgReading.bpm?.toStringAsFixed(1)} BPM'),
            if (widget.ecgReading.rawValue != null)
              _buildInfoRow('Raw Value', widget.ecgReading.rawValue!.toStringAsFixed(2)),
            if (widget.ecgReading.average != null)
              _buildInfoRow('Average Value', widget.ecgReading.average!.toStringAsFixed(2)),
            if (widget.ecgReading.maxInPeriod != null)
              _buildInfoRow('Max in Period', widget.ecgReading.maxInPeriod!.toString()),
            if (widget.ecgReading.userEmail != null && widget.ecgReading.userEmail!.isNotEmpty)
              _buildInfoRow('Recorded for User', widget.ecgReading.userEmail!),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartDiseaseRiskSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Heart Disease Risk Assessment'),
            if (_isPredicting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_heartDiseaseRiskResults != null) ...[
              _buildRiskScore(_heartDiseaseRiskResults!),
              const SizedBox(height: 16),
              _buildRiskDistribution(_heartDiseaseRiskResults!),
            ] else
              const Text('Heart disease risk prediction is not available for this record.'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRiskScore(Map<String, dynamic> results) {
    final riskScore = results['risk_score'] as double? ?? 0.0;
    final normalProb = results['normal'] as double? ?? 1.0;
    
    Color riskColor;
    String riskLabel;
    
    if (riskScore < 15) {
      riskColor = Colors.green;
      riskLabel = 'LOW RISK';
    } else if (riskScore < 40) {
      riskColor = Colors.yellow.shade800;
      riskLabel = 'MODERATE RISK';
    } else {
      riskColor = Colors.red;
      riskLabel = 'HIGH RISK';
    }
    
    return Column(
      children: [
        Text(
          'Risk Score: ${riskScore.toStringAsFixed(1)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: riskColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: riskColor.withAlpha(51),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: riskColor),
          ),
          child: Text(
            riskLabel,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: riskColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: riskScore / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(riskColor),
          minHeight: 10,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 8),
        Text(
          normalProb > 0.7 
              ? 'The ECG pattern appears normal.'
              : 'Consult with a healthcare professional for further evaluation.',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRiskDistribution(Map<String, dynamic> results) {
    final data = <String, double>{
      'Normal': results['normal'] as double? ?? 0.0,
      'Arrhythmia': results['arrhythmia'] as double? ?? 0.0,
      'AFib': results['afib'] as double? ?? 0.0,
      'Heart Attack': results['heart_attack'] as double? ?? 0.0,
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Condition Risk Distribution',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...data.entries.map((entry) {
          final percent = entry.value * 100;
          Color barColor;
          
          if (entry.key == 'Normal') {
            barColor = Colors.green;
          } else if (entry.key == 'Arrhythmia') {
            barColor = Colors.orange;
          } else if (entry.key == 'AFib') {
            barColor = Colors.deepOrange;
          } else {
            barColor = Colors.red;
          }
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text('${percent.toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: entry.value,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        if ((results['error'] as String?) != null)
          Text(
            'Note: ${results['error']}',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).hintColor,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildAnalysisSection() {
    if (_isAnalyzing) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ECG Analysis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 16),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing ECG data...'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_analysisError != null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ECG Analysis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                _analysisError!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _analyzeEcgReading,
                child: const Text('Retry Analysis'),
              ),
            ],
          ),
        ),
      );
    }

    if (_analysisResults == null) {
      return const SizedBox.shrink();
    }

    // Get the analysis probabilities
    final normalProb = _analysisResults!['normal'] as double? ?? 0.0;
    final arrhythmiaProb = _analysisResults!['arrhythmia'] as double? ?? 0.0;
    final afibProb = _analysisResults!['afib'] as double? ?? 0.0;
    final heartAttackProb = _analysisResults!['heart_attack'] as double? ?? 0.0;
    
    // Format numbers to percentage
    final formatPercent = NumberFormat.percentPattern();
    
    // Determine the most likely condition
    String primaryCondition = 'Normal';
    Color conditionColor = Colors.green;
    
    if (heartAttackProb > 0.5) {
      primaryCondition = 'Potential heart attack indicators';
      conditionColor = Colors.red;
    } else if (afibProb > 0.3) {
      primaryCondition = 'Potential atrial fibrillation';
      conditionColor = Colors.orange;
    } else if (arrhythmiaProb > 0.3) {
      primaryCondition = 'Potential arrhythmia';
      conditionColor = Colors.orangeAccent;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('ECG Analysis'),
            const SizedBox(height: 8),
            
            // Primary condition assessment
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: conditionColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: conditionColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_information, color: conditionColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      primaryCondition,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: conditionColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Rhythm Analysis Probabilities:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Probabilities list
            _buildProbabilityRow('Normal rhythm', normalProb, formatPercent, Colors.green),
            _buildProbabilityRow('Arrhythmia', arrhythmiaProb, formatPercent, Colors.orange),
            _buildProbabilityRow('Atrial fibrillation', afibProb, formatPercent, Colors.orange),
            _buildProbabilityRow('Heart attack indicators', heartAttackProb, formatPercent, Colors.red),
            
            const SizedBox(height: 16),
            const Text(
              'Note: This is an automated analysis and should not replace professional medical evaluation.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbabilityRow(String condition, double probability, NumberFormat formatter, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$condition: '),
          const Spacer(),
          Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade200,
            ),
            child: Row(
              children: [
                Container(
                  width: 100 * probability,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: color.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatter.format(probability)),
        ],
      ),
    );
  }

  Widget _buildMedicalHistorySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionTitle('Medical History'),
            if (widget.patientProfile.medicalConditions.isNotEmpty) ...[
              const Text('Medical Conditions:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.patientProfile.medicalConditions.map((condition) => Text('- $condition')),
              const SizedBox(height: 8),
            ],
            if (widget.patientProfile.medications.isNotEmpty) ...[
              const Text('Medications:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.patientProfile.medications.map((medication) => Text('- $medication')),
              const SizedBox(height: 8),
            ],
            if (widget.patientProfile.allergies.isNotEmpty) ...[
              const Text('Allergies:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.patientProfile.allergies.map((allergy) => Text('- $allergy')),
            ],
            if (widget.patientProfile.medicalConditions.isEmpty &&
                widget.patientProfile.medications.isEmpty &&
                widget.patientProfile.allergies.isEmpty)
              const Text('No relevant medical history provided.'),
          ],
        ),
      ),
    );
  }
} 