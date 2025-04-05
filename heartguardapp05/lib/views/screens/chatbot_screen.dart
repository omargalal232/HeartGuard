import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // For SocketException
import 'dart:async'; // For TimeoutException
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      if (dotenv.env['GROQ_API_KEY'] == null) {
        throw Exception("API key not found in .env file");
      }
    } catch (e) {
      debugPrint("Error loading .env: $e");
      rethrow;
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': _messageController.text});
      _messageController.clear();
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
            headers: {
              "Authorization":
                  "Bearer ${dotenv.env['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']}",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model": "llama3-70b-8192",
              "messages": [
                {
                  "role": "system",
                  "content": "You are HeartGuard, a cardiac health assistant. "
                      "Provide concise 2-3 sentence responses about heart rate, "
                      "ECG, and cardiovascular health. Always include: "
                      "'Consult a doctor for medical advice.'"
                },
                ..._messages.map(
                    (msg) => {"role": msg['role'], "content": msg['content']}),
              ],
              "temperature": 0.7,
              "max_tokens": 150,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': data['choices'][0]['message']['content'],
          });
        });
      } else {
        throw http.ClientException(
            "API Error ${response.statusCode}: ${response.body}");
      }
    } on SocketException {
      _showError("No internet connection. Please check your network.");
    } on TimeoutException {
      _showError("Request timed out. Please try again.");
    } on http.ClientException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("An unexpected error occurred");
      debugPrint("Error details: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': "⚠️ $message",
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HeartGuard Assistant'),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[850],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages.reversed.toList()[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message['role'] == 'user'
                        ? Colors.blue[800]
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message['content']!,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask about heart health...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
