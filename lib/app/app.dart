import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation_layout.dart';
import 'theme/app_theme.dart';
import '../features/auth/auth_view.dart';
import '../features/onboarding/onboarding_view.dart';
import '../features/splash/splash_view.dart';
import '../services/notification_service.dart';

enum AppFlowStep {
  splash,
  onboarding,
  auth,
  main,
}

class TrashQuestApp extends StatefulWidget {
  const TrashQuestApp({super.key});

  @override
  State<TrashQuestApp> createState() => _TrashQuestAppState();
}

class _TrashQuestAppState extends State<TrashQuestApp> {
  AppFlowStep _currentStep = AppFlowStep.splash;
  static const String _prefOnboardingCompleted = 'pref_onboarding_completed';

  Future<void> _handleSplashComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(_prefOnboardingCompleted) ?? false;

    setState(() {
      if (!onboardingDone) {
        _currentStep = AppFlowStep.onboarding;
      } else {
        _currentStep = AppFlowStep.auth;
      }
    });
  }

  Future<void> _handleOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefOnboardingCompleted, true);
    setState(() => _currentStep = AppFlowStep.auth);
  }

  void _handleLoginSuccess() {
    setState(() => _currentStep = AppFlowStep.main);
  }

  void _handleLogout() {
    setState(() => _currentStep = AppFlowStep.auth);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrashQuest',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: _buildCurrentScreen(),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentStep) {
      case AppFlowStep.splash:
        return SplashView(
          key: const ValueKey('splash_screen'),
          onComplete: _handleSplashComplete,
        );
      case AppFlowStep.onboarding:
        return OnboardingView(
          key: const ValueKey('onboarding_screen'),
          onFinish: _handleOnboardingComplete,
        );
      case AppFlowStep.auth:
        return AuthView(
          key: const ValueKey('auth_screen'),
          onLoginSuccess: _handleLoginSuccess,
        );
      case AppFlowStep.main:
        return MainNavigationLayout(
          key: const ValueKey('main_screen'),
          onLogout: _handleLogout,
        );
    }
  }
}
