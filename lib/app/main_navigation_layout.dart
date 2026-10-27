import 'package:flutter/material.dart';
import '../features/ai_assistant/ai_assistant_view.dart';
import '../features/home/home_view.dart';
import '../features/map/explore_view.dart';
import '../features/profile/profile_view.dart';
import '../features/quest/quest_view.dart';
import '../features/scanner/scanner_view.dart';

class MainNavigationLayout extends StatefulWidget {
  final VoidCallback onLogout;

  const MainNavigationLayout({super.key, required this.onLogout});

  @override
  State<MainNavigationLayout> createState() => _MainNavigationLayoutState();
}

class _MainNavigationLayoutState extends State<MainNavigationLayout> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onNavigateToExplore: () {
            _navigateToTab(1); // Navigate to Explore
          },
        ),
      ),
    );
  }

  void _openAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiAssistantView()),
    );
  }

  void _openProfile() {
    _navigateToTab(3);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeView(
        onNavigateTab: _navigateToTab,
        onOpenScanner: _openScanner,
        onOpenAssistant: _openAssistant,
        onOpenProfile: _openProfile,
      ),
      const ExploreView(),
      QuestView(onOpenProfile: _openProfile),
      ProfileView(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: SizedBox(
        width: 58,
        height: 58,
        child: FloatingActionButton(
          onPressed: _openScanner,
          backgroundColor: const Color(0xFF22C55E),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          tooltip: 'Pindai Sampah dengan AI',
          child: const Icon(Icons.qr_code_scanner_rounded, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: _currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                label: 'Beranda',
                index: 0,
              ),
              _navItem(
                icon: _currentIndex == 1 ? Icons.near_me_rounded : Icons.near_me_outlined,
                label: 'Peta',
                index: 1,
              ),
              const SizedBox(width: 48), // Gap for floating action scan button
              _navItem(
                icon: _currentIndex == 2 ? Icons.military_tech_rounded : Icons.military_tech_outlined,
                label: 'Quest',
                index: 2,
              ),
              _navItem(
                icon: _currentIndex == 3 ? Icons.person_rounded : Icons.person_outline_rounded,
                label: 'Profil',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    const activeColor = Color(0xFF16A34A);
    const inactiveColor = Color(0xFF64748B);

    return InkWell(
      onTap: () => _navigateToTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
