import 'package:flutter/material.dart';

class SupabaseConfigScreen extends StatelessWidget {
  const SupabaseConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Supabase',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Run the app with SUPABASE_URL and '
                  'SUPABASE_PUBLISHABLE_KEY dart defines to enable auth.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
