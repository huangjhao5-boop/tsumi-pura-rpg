import 'package:flutter/material.dart';

enum RetroNavTab {
  battle,
  hangar,
  showcase,
  logs,
}

class RetroBottomNavBar extends StatelessWidget {
  final RetroNavTab currentTab;
  final ValueChanged<RetroNavTab> onTabSelected;

  const RetroBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B26),
        border: Border(
          top: BorderSide(color: Color(0xFF383A59), width: 2),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            key: const Key('btn_nav_battle'),
            tab: RetroNavTab.battle,
            icon: Icons.sports_esports,
            label: '討伐',
            activeColor: const Color(0xFFFFD54F),
          ),
          _buildNavItem(
            key: const Key('btn_nav_hangar'),
            tab: RetroNavTab.hangar,
            icon: Icons.warehouse,
            label: '機庫',
            activeColor: const Color(0xFF50FA7B),
          ),
          _buildNavItem(
            key: const Key('btn_nav_showcase'),
            tab: RetroNavTab.showcase,
            icon: Icons.military_tech,
            label: '展櫃',
            activeColor: const Color(0xFFFFB86C),
          ),
          _buildNavItem(
            key: const Key('btn_nav_craft_log'),
            tab: RetroNavTab.logs,
            icon: Icons.menu_book,
            label: '日誌',
            activeColor: const Color(0xFF8BE9FD),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required Key key,
    required RetroNavTab tab,
    required IconData icon,
    required String label,
    required Color activeColor,
  }) {
    final bool isSelected = currentTab == tab;
    return InkWell(
      key: key,
      onTap: () => onTabSelected(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : Colors.white38,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
