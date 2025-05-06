import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/chatbot_service.dart';
import '../../services/ecg_service.dart';
import '../../models/ecg_reading.dart';



class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ChatbotService _chatbotService = ChatbotService();
  final ECGService _ecgService = ECGService();
  final Logger _logger = Logger();
  bool _isTyping = false;
  EcgReading? _latestReading;
  StreamSubscription? _ecgSubscription;
  String? _emergencyContact;
  final String _emergencyContactKey = 'emergency_contact';

  @override
  void initState() {
    super.initState();
    _subscribeToEcgReadings();
    _addWelcomeMessage();
    _loadEmergencyContact();
  }

  Future<void> _loadEmergencyContact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _emergencyContact = prefs.getString(_emergencyContactKey) ?? '911';
      });
    } catch (e, stackTrace) {
      _logger.e('Error loading emergency contact', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _saveEmergencyContact(String contact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emergencyContactKey, contact);
      setState(() {
        _emergencyContact = contact;
      });
    } catch (e, stackTrace) {
      _logger.e('Error saving emergency contact', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _showEmergencyContactDialog() async {
    final TextEditingController controller = TextEditingController(text: _emergencyContact);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter emergency contact number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _saveEmergencyContact(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkAndRequestPermissions() async {
    // Check SMS permission
    var smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      smsStatus = await Permission.sms.request();
      if (!smsStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permission is required to send emergency messages'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  void _subscribeToEcgReadings() {
    _ecgSubscription = _ecgService.latestReadingStream.listen(
      (reading) {
        if (mounted) {
          setState(() {
            _latestReading = reading;
          });
        }
      },
      onError: (error) {
        _logger.e('Error in ECG stream', error: error);
      },
    );
  }

  void _addWelcomeMessage() {
    _messages.add(const ChatMessage(
      text: "Hello! I'm your health assistant. I can help you monitor your heart health and provide lifestyle recommendations. How can I help you today?",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _ecgSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
      ));
      _isTyping = true;
    });

    try {
      final response = _chatbotService.generateResponse(text, latestReading: _latestReading);
      
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
          ));
        });

        // Check if this is an emergency response and offer to send SMS
        if (response.contains('⚠️ ATTENTION') || response.contains('seek immediate medical attention')) {
          _offerEmergencyContact();
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error generating response', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(const ChatMessage(
            text: "I'm sorry, I encountered an error. Please try again.",
            isUser: false,
          ));
        });
      }
    }
  }

  Future<void> _offerEmergencyContact() async {
    if (!mounted) return;

    final shouldContact = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: const Text('Would you like me to contact emergency services?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldContact == true && mounted) {
      _sendEmergencySMS();
    }
  }

  Future<void> _sendEmergencySMS() async {
    if (_emergencyContact == null || _emergencyContact!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No emergency contact number available. Please set an emergency contact.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Set Contact',
              textColor: const Color.fromARGB(255, 237, 254, 2),
              onPressed: () {
                _showEmergencyContactDialog();
              },
            ),
          ),
        );
      }
      return;
    }

    // Check permissions first
    if (!await _checkAndRequestPermissions()) {
      return;
    }

    try {
      final bpm = _latestReading?.bpm?.toString() ?? 'Unknown';
      final ecgStatus = _latestReading?.hasValidData == true ? 'Normal' : 'No data';
      final timestamp = DateTime.now().toLocal().toString();

      // Create message with clean formatting
      final message = 'EMERGENCY ALERT\n'
          'Time: $timestamp\n'
          'Heart Rate: $bpm BPM\n'
          'ECG Status: $ecgStatus\n'
          'Action Required: Immediate medical assistance needed';

      // Create properly encoded URI
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: _emergencyContact,
        queryParameters: {
          'body': message,
        },
      );

      // Log the URI for debugging
      _logger.d('Attempting to launch SMS with URI: $smsUri');

      // Try launching with different modes if needed
      if (await canLaunchUrl(smsUri)) {
        final launched = await launchUrl(
          smsUri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          throw 'Could not launch SMS app';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency SMS opened in messaging app'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw 'Could not create SMS message';
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending emergency SMS', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emergency SMS: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _sendEmergencySMS,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency),
            onPressed: _offerEmergencyContact,
            tooltip: 'Emergency Contact',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _messages[_messages.length - 1 - index];
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Flexible(
            child: TextField(
              controller: _messageController,
              onSubmitted: _handleSubmitted,
              decoration: const InputDecoration.collapsed(
                hintText: 'Ask about your health...',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleSubmitted(_messageController.text),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: const Icon(Icons.health_and_safety, color: Colors.white),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(text),
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 8.0),
              child: const CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
        ],
      ),
    );
  }
} 