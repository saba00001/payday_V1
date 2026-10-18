import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color color;
  final int branchIndex;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.color,
    required this.branchIndex,
  });
}

class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _selectedVisualIndex = 0;

  final List<_TabSpec> _tabs = const [
    _TabSpec(
      label: 'მთავარი',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      color: AppTheme.primary,
      branchIndex: 0,
    ),
    _TabSpec(
      label: 'კალენდარი',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      color: AppTheme.accentBlue,
      branchIndex: 1,
    ),
    _TabSpec(
      label: 'ისტორია',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      color: AppTheme.accentPink,
      branchIndex: 2,
    ),
    _TabSpec(
      label: 'პარამეტრები',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      color: AppTheme.secondary,
      branchIndex: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedVisualIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(AppNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shellIndex = widget.navigationShell.currentIndex;
    if (_selectedVisualIndex != shellIndex) {
      setState(() => _selectedVisualIndex = shellIndex);
    }
  }

  void _onTabTap(int visualIndex) {
    final tab = _tabs[visualIndex];
    setState(() => _selectedVisualIndex = visualIndex);
    widget.navigationShell.goBranch(
      tab.branchIndex,
      initialLocation: tab.branchIndex == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTheme.blurMedium,
              sigmaY: AppTheme.blurMedium,
            ),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.surfaceElevated.withAlpha(246),
                    AppTheme.surfaceDark.withAlpha(245),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.glassBorder, width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentBlue.withAlpha(16),
                    blurRadius: 26,
                    spreadRadius: 1,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(
                  _tabs.length,
                  (index) => Expanded(
                    child: _NavTabItem(
                      tab: _tabs[index],
                      isActive: index == _selectedVisualIndex,
                      onTap: () => _onTabTap(index),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final _TabSpec tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: tab.label,
      child: Tooltip(
        message: tab.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tab.color.withAlpha(34),
                        tab.color.withAlpha(12),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: isActive ? tab.color.withAlpha(62) : Colors.transparent,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: tab.color.withAlpha(18),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    isActive ? tab.activeIcon : tab.icon,
                    key: ValueKey(isActive),
                    color: isActive ? tab.color : AppTheme.textMuted,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? tab.color : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
