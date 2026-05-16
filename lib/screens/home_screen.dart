import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final auth = authService ?? AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Welcome, ${auth.currentUser?.email ?? 'User'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
