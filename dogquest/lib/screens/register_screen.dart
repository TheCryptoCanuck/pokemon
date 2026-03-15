import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_user_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _usernameStatus; // null = unchecked, 'checking', 'available', 'taken'
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameCtrl.removeListener(_onUsernameChanged);
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _usernameCtrl.text.trim();
    if (username.length < 3) {
      setState(() => _usernameStatus = null);
      _usernameDebounce?.cancel();
      return;
    }
    setState(() => _usernameStatus = 'checking');
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await ref
          .read(supabaseUserServiceProvider)
          .isUsernameAvailable(username);
      if (!mounted) return;
      if (_usernameCtrl.text.trim() == username) {
        setState(() => _usernameStatus = available ? 'available' : 'taken');
      }
    });
  }

  double get _passwordStrength {
    final p = _passwordCtrl.text;
    if (p.isEmpty) return 0;
    double score = 0;
    if (p.length >= 6) score += 0.25;
    if (p.length >= 10) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score += 0.25;
    if (RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) score += 0.25;
    return score;
  }

  Color get _strengthColor {
    final s = _passwordStrength;
    if (s <= 0.25) return Colors.redAccent;
    if (s <= 0.5) return Colors.orange;
    if (s <= 0.75) return Colors.yellow;
    return Colors.greenAccent;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameStatus == 'taken') {
      setState(() => _error = 'Username is already taken');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref.read(supabaseAuthServiceProvider).signUp(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            username: _usernameCtrl.text.trim(),
          );

      // Create user profile in Supabase users table
      final user = response.user;
      if (user != null) {
        await ref.read(supabaseUserServiceProvider).createProfile(user);
      }

      // Clear offline mode
      Hive.box('dogquest_player_stats').put('offline_mode', false);
      if (!mounted) return;
      context.go('/onboarding');
    } on SupabaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 8),
                  const Text(
                    'Join DogQuest and start your collection',
                    style: TextStyle(color: Colors.white54),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 32),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ).animate().shakeX(duration: 400.ms, hz: 4, amount: 6),
                  TextFormField(
                    controller: _usernameCtrl,
                    autofillHints: const [AutofillHints.username],
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Username').copyWith(
                      suffixIcon: _usernameStatus == null
                          ? null
                          : _usernameStatus == 'checking'
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                                  ),
                                )
                              : Icon(
                                  _usernameStatus == 'available' ? Icons.check_circle : Icons.cancel,
                                  color: _usernameStatus == 'available' ? Colors.greenAccent : Colors.redAccent,
                                  size: 20,
                                ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 3) return 'At least 3 characters';
                      if (v.trim().length > 50) return 'Max 50 characters';
                      if (_usernameStatus == 'taken') return 'Username is taken';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Email'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Password'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (_passwordCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _passwordStrength,
                        backgroundColor: Colors.white12,
                        color: _strengthColor,
                        minHeight: 4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Already have an account? Sign in',
                      style: TextStyle(color: Colors.amber),
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
