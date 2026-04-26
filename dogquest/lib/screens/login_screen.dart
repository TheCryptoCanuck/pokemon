import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/services/supabase_auth_service.dart';
import 'package:dogquest/services/supabase_user_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  final _shakeKey = GlobalKey();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref.read(supabaseAuthServiceProvider).signIn(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      // Fetch/cache user profile on login
      final user = response.user;
      if (user != null) {
        try {
          await ref.read(supabaseUserServiceProvider).fetchProfile(user.id);
        } catch (_) {
          // Non-critical — profile will sync later
        }
      }
      // Clear offline mode now that user is authenticated
      Hive.box('dogquest_player_stats').put('offline_mode', false);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/identify');
      }
    } on SupabaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error = 'Enter your email above, then tap Forgot Password',
      );
      return;
    }
    try {
      await ref.read(supabaseAuthServiceProvider).resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent — check your inbox'),
        ),
      );
    } on SupabaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _continueOffline() {
    Hive.box('dogquest_player_stats').put('offline_mode', true);
    context.go('/identify');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🐶', style: TextStyle(fontSize: 64))
                        .animate()
                        .fadeIn()
                        .scale(),
                    const SizedBox(height: 12),
                    const Text(
                      'DogQuest',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to sync your collection',
                      style: TextStyle(color: Colors.white54),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 32),
                    if (_error != null)
                      Container(
                        key: _shakeKey,
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ).animate().shakeX(duration: 400.ms, hz: 4, amount: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Password'),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : _forgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text(
                        'Create an account',
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _continueOffline,
                      child: const Text(
                        'Continue Offline',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => context.push('/privacy'),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      filled: true,
      fillColor: bgCard,
    );
  }
}
