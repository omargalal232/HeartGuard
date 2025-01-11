import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/user_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase App',
      theme: ThemeData.light(),
      home: UserManagementScreen(),
    );
  }
}

class UserManagementScreen extends StatelessWidget {
  final UserService userService = UserService();

  UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Management')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Example: Create a new user with a unique ID
            String userId = DateTime.now().millisecondsSinceEpoch.toString(); // Generate a unique ID
            UserModel newUser = UserModel(id: userId, name: 'Ahmed', email: 'Ahmed@example.com');
            await userService.createUser(newUser);
            print('User created with ID: $userId');
          },
          child: Text('Create User'),
        ),
      ),
    );
  }
}
