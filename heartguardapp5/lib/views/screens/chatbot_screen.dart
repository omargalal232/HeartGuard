import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
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
  bool _isListening = false;
  EcgReading? _latestReading;
  StreamSubscription? _ecgSubscription;
  String? _emergencyContact;
  final String _emergencyContactKey = 'emergency_contact';
  final ScrollController _scrollController = ScrollController();

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
    _messages.add(ChatMessage(
      text: "Hello! I'm your HeartGuard health assistant. I can help you monitor your heart health and provide personalized recommendations. How can I help you today?",
      isUser: false,
      messageType: MessageType.greeting,
      timestamp: DateTime.now(),
    ));
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _addWelcomeMessage();
      // Reset the context in the chatbot service
      _chatbotService.resetContext();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _ecgSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        messageType: MessageType.user,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate typing delay for more natural conversation
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final response = _chatbotService.generateResponse(text, latestReading: _latestReading);
      
      if (mounted) {
        setState(() {
          _isTyping = false;
          
          // Determine the message type based on content
          MessageType messageType = MessageType.normal;
          if (response.contains('⚠️')) {
            messageType = MessageType.emergency;
          } else if (response.contains("I don't have")) {
            messageType = MessageType.warning;
          } else if (response.contains('Heart Rate:') || response.contains('ECG Pattern:')) {
            messageType = MessageType.healthStatus;
          } else if (response.contains('1. Exercise') || response.contains('recommendations')) {
            messageType = MessageType.recommendation;
          }
          
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            messageType: messageType,
            timestamp: DateTime.now(),
          ));
        });

        _scrollToBottom();

        // Check if this is an emergency response and offer to send SMS
        if (response.contains('⚠️ ATTENTION') || 
            response.contains('⚠️ URGENT') || 
            response.contains('seek immediate medical attention')) {
          _offerEmergencyContact();
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error generating response', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: "I'm sorry, I encountered an error processing your request. Please try again.",
            isUser: false,
            messageType: MessageType.error,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startVoiceInput() {
    // This would be connected to a speech-to-text service
    setState(() {
      _isListening = true;
    });

    // Simulate voice recognition (would be replaced with actual voice API)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isListening = false;
          _messageController.text = "Tell me about my heart health";  // Sample recognized text
        });
      }
    });
  }

  Future<void> _sendEmergencySMS() async {
    if (_emergencyContact == null || _emergencyContact!.isEmpty) {
      await _showEmergencyContactDialog();
      if (_emergencyContact == null || _emergencyContact!.isEmpty) {
        return;
      }
    }

    final hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) return;

    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: _emergencyContact,
        queryParameters: {
          'body': 'EMERGENCY: I need medical help. This is an emergency alert sent from my HeartGuard app.',
        },
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              text: "Emergency SMS launched. Please complete sending the message.",
              isUser: false,
              messageType: MessageType.emergency,
              timestamp: DateTime.now(),
            ));
          });
          _scrollToBottom();
        }
      } else {
        throw Exception('Could not launch SMS');
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending emergency SMS', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send emergency message. Please call emergency services directly.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _offerEmergencyContact() async {
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: const Text('How would you like to contact emergency services?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('sms'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send SMS'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('call'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );

    if (choice == 'sms' && mounted) {
      _sendEmergencySMS();
    } else if (choice == 'call' && mounted) {
      _makeEmergencyCall();
    }
  }

  Future<void> _makeEmergencyCall() async {
    try {
      final Uri callUri = Uri(
        scheme: 'tel',
        path: _emergencyContact ?? '911',
      );

      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        throw Exception('Could not launch phone call');
      }
    } catch (e, stackTrace) {
      _logger.e('Error making emergency call', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to make emergency call. Please dial emergency services manually.'),
            backgroundColor: Colors.red,
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
            icon: const Icon(Icons.edit),
            onPressed: _showEmergencyContactDialog,
            tooltip: 'Set Emergency Contact',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetConversation,
            tooltip: 'Reset Conversation',
          ),
          IconButton(
            icon: const Icon(Icons.emergency),
            onPressed: _offerEmergencyContact,
            tooltip: 'Emergency Contact',
          ),
        ],
      ),
      body: Column(
        children: [
          // Heart rate indicator
          if (_latestReading?.bpm != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
              color: _getHeartRateColor(_latestReading!.bpm!).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: _getHeartRateColor(_latestReading!.bpm!),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Heart Rate: ${_latestReading!.bpm!.toInt()} BPM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getHeartRateColor(_latestReading!.bpm!),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _handleSubmitted('Tell me about my heart rate'),
                    child: const Text('Analyze'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _messages[_messages.length - 1 - index];
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    radius: 16,
                    child: const Icon(Icons.health_and_safety, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const TypingIndicator(),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Color _getHeartRateColor(double bpm) {
    if (bpm < 60) return Colors.blue.shade700;
    if (bpm > 100) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  Widget _buildTextComposer() {
    return Column(
      children: [
        // Quick reply chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              _buildQuickReplyChip('Heart rate'),
              _buildQuickReplyChip('My health status'),
              _buildQuickReplyChip('ECG analysis'),
              _buildQuickReplyChip('Exercise tips'),
              _buildQuickReplyChip('Stress management'),
              _buildQuickReplyChip('Heart-healthy diet'),
            ],
          ),
        ),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              // Voice input button
              IconButton(
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red : Colors.grey.shade200,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                onPressed: _startVoiceInput,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: _handleSubmitted,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Ask about your heart health...',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () => _handleSubmitted(_messageController.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildQuickReplyChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _handleSubmitted(label),
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        labelStyle: TextStyle(color: Theme.of(context).primaryColor),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          children: [
            _buildDot(0),
            const SizedBox(width: 3),
            _buildDot(1),
            const SizedBox(width: 3),
            _buildDot(2),
          ],
        );
      },
    );
  }
  
  Widget _buildDot(int index) {
    double delay = index * 0.3;
    final progress = (_controller.value + delay) % 1.0;
    
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: progress < 0.5 ? progress * 2 : (1 - progress) * 2),
        shape: BoxShape.circle,
      ),
    );
  }
}

enum MessageType {
  user,
  normal,
  emergency,
  warning,
  healthStatus,
  recommendation,
  greeting,
  error
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final MessageType messageType;
  final DateTime timestamp;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageType = MessageType.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  margin: const EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    backgroundColor: _getAvatarColor(context),
                    child: const Icon(Icons.health_and_safety, color: Colors.white),
                  ),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
                  decoration: BoxDecoration(
                    color: _getMessageColor(context),
                    borderRadius: BorderRadius.circular(18.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: _getTextColor(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
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
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 40.0, right: 8.0),
            child: Text(
              _formatTimestamp(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp() {
    return DateFormat('h:mm a').format(timestamp);
  }

  Color _getAvatarColor(BuildContext context) {
    switch (messageType) {
      case MessageType.emergency:
        return Colors.red;
      case MessageType.warning:
        return Colors.orange;
      case MessageType.error:
        return Colors.red.shade300;
      case MessageType.healthStatus:
        return Colors.green;
      case MessageType.recommendation:
        return Colors.blue;
      case MessageType.greeting:
        return Colors.purple;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Color _getMessageColor(BuildContext context) {
    if (isUser) {
      return Colors.blue.shade100;
    }

    switch (messageType) {
      case MessageType.emergency:
        return Colors.red.shade50;
      case MessageType.warning:
        return Colors.orange.shade50;
      case MessageType.healthStatus:
        return Colors.green.shade50;
      case MessageType.recommendation:
        return Colors.blue.shade50;
      case MessageType.error:
        return Colors.red.shade50;
      case MessageType.greeting:
        return Colors.purple.shade50;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getTextColor(BuildContext context) {
    if (isUser) {
      return Colors.black87;
    }

    switch (messageType) {
      case MessageType.emergency:
        return Colors.red.shade900;
      case MessageType.warning:
        return Colors.orange.shade900;
      case MessageType.error:
        return Colors.red.shade900;
      case MessageType.healthStatus:
        return Colors.green.shade900;
      case MessageType.recommendation:
        return Colors.blue.shade900;
      case MessageType.greeting:
        return Colors.purple.shade900;
      default:
        return Colors.black87;
    }
  }
} 