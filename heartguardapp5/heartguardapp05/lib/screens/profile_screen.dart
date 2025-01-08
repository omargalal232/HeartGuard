import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatelessWidget {
  final FirestoreService firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: StreamBuilder(
        stream: firestoreService.fetchDocuments('profiles'),
        builder: (context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data.docs.length,
              itemBuilder: (context, index) {
                final profile = snapshot.data.docs[index];
                return ListTile(
                  title: Text(profile['name']),
                  subtitle: Text(profile['email']),
                );
              },
            );
          } else {
            return Center(child: Text('No profiles found.'));
          }
        },
      ),
    );
  }
}
