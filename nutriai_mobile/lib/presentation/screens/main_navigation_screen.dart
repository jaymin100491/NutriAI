import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'dashboard/dashboard_screen.dart';
import 'diet_plan/diet_plan_list_screen.dart';
import 'chat/ai_chat_screen.dart';
import 'recipes/recipes_list_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DietPlanListScreen(),
    const AiChatScreen(),
    const RecipesListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

/// Allows child widgets to switch tabs
class MainNavController {
  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    state?.setState(() => state._selectedIndex = index);
  }
}
