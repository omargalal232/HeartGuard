import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Assistant'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.all(16.0),
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask about health advice...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (message.isUser) _buildAvatar(isUser: true),
        ],
      ),
    );
  }

  Widget _buildAvatar({bool isUser = false}) {
    return CircleAvatar(
      backgroundColor:
          isUser ? Colors.blue : Theme.of(context).colorScheme.secondary,
      child: Icon(
        isUser ? Icons.person : Icons.android,
        color: Colors.white,
      ),
    );
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          text: _controller.text,
          isUser: true,
        ));
        
        // Add bot response
        _messages.add(ChatMessage(
          text: _getBotResponse(_controller.text),
          isUser: false,
        ));
        
        _controller.clear();
      });
      
      // Scroll to the bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _getBotResponse(String query) {
    query = query.toLowerCase();
    if (query.contains('exercise') || query.contains('workout')) {
      return 'Regular exercise is important for heart health. Aim for at least 30 minutes of moderate activity most days of the week. This can include walking, swimming, or cycling.';
    } else if (query.contains('diet') || query.contains('food') || query.contains('eat')) {
      return 'A heart-healthy diet includes plenty of fruits, vegetables, whole grains, and lean proteins. Try to limit saturated fats, added sugars, and excessive salt.';
    } else if (query.contains('sleep')) {
      return 'Getting 7-9 hours of quality sleep each night is crucial for heart health. Maintain a regular sleep schedule and create a relaxing bedtime routine.';
    } else if (query.contains('stress')) {
      return 'Managing stress is important for heart health. Try relaxation techniques like deep breathing, meditation, or yoga. Regular exercise can also help reduce stress.';
    } else if (query.contains('blood pressure')) {
      return 'Normal blood pressure is typically around 120/80 mmHg. Regular monitoring, a healthy diet, exercise, and stress management can help maintain healthy blood pressure levels.';
    } else {
      return 'I can provide information about exercise, diet, sleep, stress management, and blood pressure. What would you like to know more about?';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
} 