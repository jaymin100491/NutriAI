import 'package:flutter/material.dart';
import 'admin_console_screen.dart';

/// Compatibility entry → unified Operations console (Patients tab).
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminConsoleScreen(initialTab: 1);
  }
}
