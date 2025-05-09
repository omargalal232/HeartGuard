import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ecg_reading.dart';
import '../../models/profile_model.dart';
import '../../services/ecg_service.dart';
import '../../services/profile_service.dart';
import '../medical_record_page.dart';

class MedicalRecordsListScreen extends StatefulWidget {
  const MedicalRecordsListScreen({super.key});

  @override
  State<MedicalRecordsListScreen> createState() => _MedicalRecordsListScreenState();
}

class _MedicalRecordsListScreenState extends State<MedicalRecordsListScreen> {
  List<EcgReading>? _ecgReadings;
  ProfileModel? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load the current user's profile
      final profileService = ProfileService();
      final profile = await profileService.getCurrentUserProfile();
      
      // Load ECG readings for the current user
      final ecgService = ECGService();
      final readings = await ecgService.getEcgReadingsForUser(profile.email);

      setState(() {
        _userProfile = profile;
        _ecgReadings = readings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading medical records: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_ecgReadings == null || _ecgReadings!.isEmpty) {
      return const Center(
        child: Text('No ECG readings found. Monitor your heart to create records.'),
      );
    }

    return ListView.builder(
      itemCount: _ecgReadings!.length,
      itemBuilder: (context, index) {
        final reading = _ecgReadings![index];
        return _buildEcgReadingCard(reading);
      },
    );
  }

  Widget _buildEcgReadingCard(EcgReading reading) {
    final dateTime = reading.dateTime;
    final dateTimeFormatted = dateTime != null
        ? DateFormat('MMM d, yyyy - h:mm a').format(dateTime)
        : 'Unknown date';

    final hasValidBpm = reading.bpm != null;
    final bpmText = hasValidBpm ? '${reading.bpm!.toInt()} BPM' : 'BPM: --';
    
    // Determine if the heart rate is outside normal range
    final isAbnormal = hasValidBpm && 
        (reading.bpm! < 60 || reading.bpm! > 100);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          Icons.favorite,
          color: isAbnormal ? Colors.red : Colors.green,
          size: 36,
        ),
        title: Text(dateTimeFormatted),
        subtitle: Text(bpmText),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (_userProfile != null) {
            Navigator.pushNamed(
              context,
              MedicalRecordPage.routeName,
              arguments: {
                'patientProfile': _userProfile,
                'ecgReading': reading,
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User profile not available')),
            );
          }
        },
      ),
    );
  }
} 