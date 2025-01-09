import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/realtime_database_service.dart';
import '../../models/user_model.dart';

/// Main screen of the application displaying user data and sensor information.
/// Provides navigation to WebSocket monitoring and user authentication management.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isLoading = false;

  /// Handles user sign out with proper error handling
  Future<void> _handleSignOut(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Navigates to the WebSocket monitoring screen
  void _navigateToWebSocket(BuildContext context) {
    Navigator.pushNamed(context, '/websocket');
  }

  /// Builds an error widget with a retry button
  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleSignOut(context),
            ),
        ],
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _databaseService.fetchData('users'),
        builder: (context, AsyncSnapshot<List<UserModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return _buildErrorWidget(
              snapshot.error.toString(),
              () => setState(() {}), // Trigger rebuild to retry
            );
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(
              child: Text('No users found. Start monitoring to collect data.'),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: ListTile(
                  title: Text(user.name ?? 'Unknown User'),
                  subtitle: Text(user.email ?? 'No email'),
                  trailing: Icon(
                    Icons.circle,
                    color: user.isActive == true ? Colors.green : Colors.grey,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToWebSocket(context),
        icon: const Icon(Icons.sensors),
        label: const Text('WebSocket Sensor'),
      ),
    );
  }
} 