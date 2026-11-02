import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/onboarding_prefs.dart';
import '../../providers/auth_provider.dart';
import '../labs/paste_labs_screen.dart';
import '../main_navigation_screen.dart';
import '../onboarding/intent_onboarding_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignup = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) {
        ref.read(authProvider.notifier).resetLoading();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _routeAfterAuth({required bool isNewSignup}) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      if (authState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authState.error!), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final user = authState.user;
    final doneIntent = await OnboardingPrefs.hasCompletedIntent(user?.id);
    // New signups and anyone who hasn't picked an intent see the Fitia-style chooser.
    if (isNewSignup || !doneIntent) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const IntentOnboardingScreen()),
      );
      return;
    }

    final skipLabs = user?.isAdmin == true || !authState.needsLabImport;
    final next = skipLabs ? const MainNavigationScreen() : const PasteLabsScreen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final signup = _isSignup;

    if (signup) {
      await ref.read(authProvider.notifier).signup(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );
    } else {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }

    if (!mounted) return;
    await _routeAfterAuth(isNewSignup: signup);
  }

  Future<void> _useDemo() async {
    _emailController.text = 'jaymin@nutriai.app';
    _passwordController.text = 'demo';
    setState(() => _isSignup = false);
    await ref.read(authProvider.notifier).login('jaymin@nutriai.app', 'demo');
    if (!mounted) return;
    await _routeAfterAuth(isNewSignup: false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: size.width > 560 ? 440 : 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.28),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'NutriAI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignup
                              ? 'Create your account — tell us what you want to change, then we’ll build your plan.'
                              : 'Lab-aware nutrition coaching that feels as polished as the best consumer apps.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.borderSubtle),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (_isSignup) ...[
                                TextFormField(
                                  controller: _firstNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'First name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Enter your first name' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _lastNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Last name (optional)',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Enter your email' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Enter your password';
                                  if (_isSignup && v.length < 4) return 'Use at least 4 characters';
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: authState.isLoading ? null : _submit,
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(_isSignup ? 'Continue' : 'Sign in'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: authState.isLoading
                                    ? null
                                    : () => setState(() => _isSignup = !_isSignup),
                                child: Text(
                                  _isSignup
                                      ? 'Already have an account? Sign in'
                                      : 'New here? Create an account',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: authState.isLoading ? null : _useDemo,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Try seeded demo account'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Wellness education only — not a medical device. '
                          'Always consult your healthcare provider for clinical decisions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
