import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/onboarding_prefs.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/craft/craft.dart';
import '../admin/admin_console_screen.dart';
import '../admin/sample_lab_order_screen.dart';
import '../auth/login_screen.dart';
import '../diet_plan/diet_plan_history_screen.dart';
import '../goals/goals_screen.dart';
import '../lab_results/lab_results_list_screen.dart';
import '../labs/paste_labs_screen.dart';
import '../onboarding/intent_onboarding_screen.dart';
import 'dietary_preferences_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user).craftIn(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TrustBanner(
                  verified: true,
                  title: 'Your coaching profile',
                  subtitle:
                      'Labs, goals, and preferences drive the nutrition engine and Coach context.',
                  sources: const ['privacy: your account only'],
                ).craftIn(delayMs: 40),
              ),
              const SizedBox(height: 8),
              _buildSection('Health data', [
                _buildListTile(context, Icons.auto_awesome_outlined, 'What I want to change', () async {
                  await OnboardingPrefs.resetIntent(user?.id);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IntentOnboardingScreen(forceShow: true),
                    ),
                  );
                }),
                _buildListTile(context, Icons.science_outlined, 'Lab results', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LabResultsListScreen()));
                }),
                _buildListTile(context, Icons.upload_file_outlined, 'Upload / paste labs', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PasteLabsScreen(allowSkip: false)),
                  );
                }),
                _buildListTile(context, Icons.flag_outlined, 'Health goals', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen()));
                }),
                _buildListTile(context, Icons.restaurant_outlined, 'Dietary preferences', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DietaryPreferencesScreen()),
                  );
                }),
                _buildListTile(context, Icons.history_rounded, 'Past diet plans', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DietPlanHistoryScreen()),
                  );
                }),
              ]).craftIn(delayMs: 80),
              if (user?.isAdmin == true)
                _buildSection('Administration', [
                  _buildListTile(context, Icons.admin_panel_settings_outlined, 'Operations console', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminConsoleScreen()),
                    );
                  }),
                ]),
              _buildSection('Lab tools', [
                _buildListTile(context, Icons.description_outlined, 'Sample lab order', () {
                  if (user == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SampleLabOrderScreen(
                        userName: user.fullName,
                        adminView: false,
                      ),
                    ),
                  );
                }),
              ]).craftIn(delayMs: 110),
              _buildSection('Account', [
                _buildListTile(
                  context,
                  Icons.logout_rounded,
                  'Log out',
                  () => _showLogoutDialog(context, ref),
                  isDestructive: true,
                ),
              ]).craftIn(delayMs: 140),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'NutriAI · Version 1.0.0',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(user) {
    final initial = (user?.firstName?.isNotEmpty == true)
        ? user!.firstName.substring(0, 1).toUpperCase()
        : 'U';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'Member',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                ProvenanceChip(
                  label: (user?.subscriptionTier ?? 'free').toString().toUpperCase(),
                  icon: Icons.workspace_premium_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(children: items),
          ),
        ],
      ),
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
      leading: Icon(icon, color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          color: isDestructive ? AppTheme.errorColor : AppTheme.ink,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDestructive ? AppTheme.errorColor : AppTheme.textSecondaryColor,
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log out', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'You’ll need to sign in again to see your labs and plan.',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
