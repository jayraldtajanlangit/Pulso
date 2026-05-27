import 'package:flutter/material.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
