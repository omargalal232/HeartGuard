import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:heartguard/services/firestore_service.dart';
import 'package:heartguard/services/auth_service.dart';
import 'package:heartguard/models/user_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HeartGuard'),
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestoreService.getUser(userId),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final user = snapshot.data!;
            return Center(
              child: Text('Welcome, ${user.email}'),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
} 