import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/emergency_contact_model.dart';
import 'onboarding_screen.dart';
import 'add_emergency_contact_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: Theme.of(context).colorScheme.primary),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        children: [
          // User Information Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Display User Email
                Text('User Email: ${authService.currentUser?.email}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to Add Emergency Contact Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddEmergencyContactScreen()),
                    );
                  },
                  child: const Text('Add Emergency Contact'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await authService.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                    );
                  },
                  child: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Set log out button color to red
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}