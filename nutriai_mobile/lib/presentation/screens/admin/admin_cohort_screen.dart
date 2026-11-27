import 'package:flutter/material.dart';
import 'admin_console_screen.dart';

/// Compatibility entry → unified Operations console (Cohort tab).
class AdminCohortScreen extends StatelessWidget {
  const AdminCohortScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminConsoleScreen(initialTab: 2);
  }
}
