import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../goals/goals_screen.dart';
import '../lab_results/lab_results_list_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'dietary_preferences_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(user),
            const SizedBox(height: 16),
            _buildSection('Account', [
              _buildListTile(context, Icons.person, 'Personal Information', () {}),
              _buildListTile(context, Icons.science, 'Lab Results', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LabResultsListScreen()));
              }),
              _buildListTile(context, Icons.favorite, 'Health Goals', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen()));
              }),
              _buildListTile(context, Icons.restaurant, 'Dietary Preferences', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DietaryPreferencesScreen()),
                );
              }),
              _buildListTile(context, Icons.notification_important, 'Allergies', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DietaryPreferencesScreen()),
                );
              }),
            ]),
            _buildSection('Settings', [
              _buildListTile(context, Icons.notifications, 'Notifications', () {}),
              _buildListTile(context, Icons.language, 'Language', () {}),
              _buildListTile(context, Icons.dark_mode, 'Dark Mode', () {}),
            ]),
            _buildSection('Support', [
              _buildListTile(context, Icons.help, 'Help Center', () {}),
              _buildListTile(context, Icons.privacy_tip, 'Privacy Policy', () {}),
              _buildListTile(context, Icons.article, 'Terms of Service', () {}),
            ]),
            _buildSection('Account Actions', [
              _buildListTile(
                context,
                Icons.logout,
                'Log Out',
                () => _showLogoutDialog(context, ref),
                isDestructive: true,
              ),
            ]),
            const SizedBox(height: 32),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Text(
              user?.firstName.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.fullName ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user?.subscriptionTier?.toUpperCase() ?? 'FREE',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppTheme.primaryColor),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.red : null),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
