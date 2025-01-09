import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/profile_model.dart';
import '../widgets/custom_text_field.dart';

/// Screen that displays and allows editing of user profile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  bool _isLoading = true;
  bool _isEditing = false;
  ProfileModel? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Loads the current user's profile
  Future<void> _loadProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to view your profile';
        });
        return;
      }

      final profile = await _firestoreService.getProfile(user.uid);
      if (profile == null) {
        setState(() {
          _isLoading = false;
          _error = 'Profile not found';
        });
        return;
      }

      setState(() {
        _profile = profile;
        _nameController.text = profile.name ?? '';
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message ?? 'Failed to load profile';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An unexpected error occurred';
      });
    }
  }

  /// Updates the user's profile
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedProfile = _profile!.copyWith(
        name: _nameController.text.trim(),
        lastActive: DateTime.now(),
      );

      await _firestoreService.updateProfile(updatedProfile);

      setState(() {
        _profile = updatedProfile;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to update profile'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isEditing = false),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  (_profile?.name?.isNotEmpty == true 
                    ? _profile!.name![0] 
                    : _profile!.email[0]).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isEditing)
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Name',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Name'),
                  subtitle: Text(_profile?.name ?? 'Not set'),
                ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(_profile?.email ?? ''),
              ),
              if (_profile?.lastActive != null) ...[
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Last Active'),
                  subtitle: Text(
                    _profile!.lastActive!.toLocal().toString(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (_isEditing)
                ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Save Changes'),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 