import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_providers.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabase();
  runApp(const ProviderScope(child: MyApp()));
}

class AuthKeys {
  static const emailField = Key('auth_email_field');
  static const passwordField = Key('auth_password_field');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F4),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD4DDD7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD4DDD7)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (!authState.isConfigured) {
      return const SupabaseConfigScreen();
    }

    if (authState.isSignedIn) {
      return const AccountScreen();
    }

    return const AuthScreen();
  }
}

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

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to Pulso',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to sync your workspace.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: AuthKeys.emailField,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: AuthKeys.passwordField,
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _StatusText(message: state.errorMessage!, isError: true),
                  ],
                  if (state.infoMessage != null) ...[
                    const SizedBox(height: 14),
                    _StatusText(message: state.infoMessage!, isError: false),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: state.isLoading
                        ? null
                        : () => controller.signIn(
                              email: _emailController.text,
                              password: _passwordController.text,
                            ),
                    child: Text(state.isLoading ? 'Working...' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: state.isLoading
                        ? null
                        : () => controller.signUp(
                              email: _emailController.text,
                              password: _passwordController.text,
                            ),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final email = state.session?.email ?? 'Signed-in user';

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
                const SizedBox(height: 22),
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

class _StatusText extends StatelessWidget {
  const _StatusText({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
