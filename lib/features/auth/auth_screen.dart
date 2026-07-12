import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/services/auth_service.dart";

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignIn = true;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    final authService = ref.read(authServiceProvider);
    try {
      if (_isSignIn) {
        await authService.signInWithEmail(_emailController.text, _passwordController.text);
      } else {
        await authService.signUpWithEmail(_emailController.text, _passwordController.text);
      }
      if (mounted) context.go(AppConstants.routeHome);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _guestMode() async {
    try {
      await ref.read(authServiceProvider).signInAnonymously();
      if (mounted) context.go(AppConstants.routeHome);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_isSignIn ? "Welcome back" : "Create account", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 32),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
              const SizedBox(height: 8),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: Text(_isSignIn ? "Sign In" : "Sign Up")),
              TextButton(onPressed: () => setState(() => _isSignIn = !_isSignIn), child: Text(_isSignIn ? "Create account" : "Already have an account?")),
              TextButton(onPressed: _guestMode, child: const Text("Continue as Guest")),
            ],
          ),
        ),
      ),
    );
  }
}
