import 'package:flutter/material.dart';

class HeartSoundHistoryScreen extends StatelessWidget {
  const HeartSoundHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Sound History'),
      ),
      body: const Center(
        child: Text('History will be shown here.'),
      ),
    );
  }
} 