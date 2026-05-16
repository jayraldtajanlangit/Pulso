import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'post_creation_screen.dart';
import 'profile_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final session = state.session;
    final email = session?.email ?? 'Signed-in user';

    return Scaffold(
      appBar: AppBar(title: const Text('Pulso')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You are signed in',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(email),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('viewProfileButton'),
                  onPressed: session == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProfileScreen(userId: session.userId),
                            ),
                          ),
                  child: const Text('View Profile'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('createPostButton'),
                  onPressed: session == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PostCreationScreen(userId: session.userId),
                            ),
                          ),
                  child: const Text('Create Post'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: state.isLoading
                      ? null
                      : () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
