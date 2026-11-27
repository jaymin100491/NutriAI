import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/dio_client.dart';
import '../widgets/bottom_nav_bar.dart';
import 'dashboard/dashboard_screen.dart';
import 'diet_plan/diet_plan_list_screen.dart';
import 'labs/lab_trends_screen.dart';
import 'chat/ai_chat_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _keepAliveTimer;

  /// Free Render spins down after ~15m idle; ping well under that.
  static const _keepAliveInterval = Duration(minutes: 8);

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DietPlanListScreen(),
    const LabTrendsScreen(),
    const AiChatScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pingServer();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) => _pingServer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAliveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pingServer();
    }
  }

  Future<void> _pingServer() async {
    try {
      await DioClient().dio.get(
            '/',
            options: Options(
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (_) => true,
            ),
          );
    } catch (_) {
      // Best-effort wake; Coach/Plan requests still retry on cold start.
    }
  }

  void switchTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: switchTab,
      ),
    );
  }
}

/// Allows child widgets to switch tabs
class MainNavController {
  static void switchToTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_MainNavigationScreenState>()?.switchTab(index);
  }
}
