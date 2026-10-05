import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../main_navigation_screen.dart';

class OktaCallbackScreen extends ConsumerStatefulWidget {
  final String code;
  final String state;

  const OktaCallbackScreen({
    super.key,
    required this.code,
    required this.state,
  });

  @override
  ConsumerState<OktaCallbackScreen> createState() => _OktaCallbackScreenState();
}

class _OktaCallbackScreenState extends ConsumerState<OktaCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishLogin());
  }

  Future<void> _finishLogin() async {
    try {
      await ref.read(authProvider.notifier).completeOktaLogin(
            code: widget.code,
            state: widget.state,
          );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Completing Labcorp sign-in…'),
          ],
        ),
      ),
    );
  }
}
