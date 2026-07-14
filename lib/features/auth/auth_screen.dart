import "dart:ui";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:firebase_auth/firebase_auth.dart";
import "../../core/theme/app_colors.dart";
import "../../core/theme/app_theme.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/errors/app_exception.dart";

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) context.go(AppConstants.routeHome);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(e.message ?? "Google sign-in failed");
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guestMode() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInAnonymously();
    } catch (_) {}
    if (mounted) context.go(AppConstants.routeHome);
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.accent),
    );
  }

  void _showEmailSignIn() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.sheetRadius)),
      ),
      builder: (_) => const _EmailSignInSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/logo2.png",
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  "Welcome to Libora",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Your privacy-first reading companion",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _GlassButton(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text("Continue with Google"),
                  ),
                ),
                const SizedBox(height: 16),
                _GlassButton(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _showEmailSignIn,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text("Continue with Email"),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _guestMode,
                  child: Text(
                    "Continue as Guest",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  const _GlassButton({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardDark.withOpacity(0.35),
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _EmailSignInSheet extends ConsumerStatefulWidget {
  const _EmailSignInSheet();

  @override
  ConsumerState<_EmailSignInSheet> createState() => _EmailSignInSheetState();
}

class _EmailSignInSheetState extends ConsumerState<_EmailSignInSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignIn = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });
    final authService = ref.read(authServiceProvider);
    try {
      if (_isSignIn) {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await authService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        context.go(AppConstants.routeHome);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Authentication failed");
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isSignIn ? "Sign In" : "Create Account",
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return "Email is required";
                if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(value.trim())) {
                  return "Enter a valid email";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: _isSignIn ? TextInputAction.done : TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return "Password is required";
                if (value.length < 6) return "Password must be at least 6 characters";
                return null;
              },
            ),
            if (!_isSignIn) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                validator: (value) {
                  if (value != _passwordController.text) return "Passwords do not match";
                  return null;
                },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                    )
                  : Text(_isSignIn ? "Sign In" : "Sign Up"),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _isSignIn = !_isSignIn;
                _error = null;
              }),
              child: Text(
                _isSignIn ? "Don't have an account? Sign up" : "Already have an account? Sign in",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
