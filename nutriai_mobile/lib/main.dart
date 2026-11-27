import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/onboarding_prefs.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/labs/paste_labs_screen.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/screens/onboarding/intent_onboarding_screen.dart';
import 'presentation/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: NutriAIApp()));
}

class NutriAIApp extends ConsumerWidget {
  const NutriAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'NutriAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AppEntry(),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      final user = authState.user;
      final doneIntent = await OnboardingPrefs.hasCompletedIntent(user?.id);
      if (!mounted) return;

      if (!doneIntent) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const IntentOnboardingScreen()),
        );
        return;
      }

      final skipLabs = user?.isAdmin == true || !authState.needsLabImport;
      final next = skipLabs ? const MainNavigationScreen() : const PasteLabsScreen();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 22),
            const Text(
              'NutriAI',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6),
            ),
            const SizedBox(height: 8),
            const Text(
              'Personalized nutrition from your labs',
              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
