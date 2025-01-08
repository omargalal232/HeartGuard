import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/realtime_database_service.dart';
import '../services/firebase_auth_service.dart';
import 'websocket_screen.dart';

class HomeScreen extends StatelessWidget {
  final RealtimeDatabaseService databaseService = RealtimeDatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: databaseService.fetchData('users'),
        builder: (context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data.children.length,
              itemBuilder: (context, index) {
                final user = snapshot.data.children.elementAt(index);
                return ListTile(
                  title: Text(user.key),
                  subtitle: Text(user.value.toString()),
                );
              },
            );
          } else {
            return Center(child: Text('No data found.'));
          }
        },
      ),
      floatingActionButton: ListTile(
        leading: Icon(Icons.sensors),
        title: Text('WebSocket Sensor'),
        onTap: () {
          Navigator.pushNamed(context, WebSocketScreen.routeName);
        },
      ),
    );
  }
}
