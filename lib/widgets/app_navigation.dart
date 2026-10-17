import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int? branchIndex;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.branchIndex,
  });
}

class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation>
    with SingleTickerProviderStateMixin {
  int _selectedVisualIndex = 0;
  late AnimationController _animController;

  final List<_TabSpec> _tabs = const [
    _TabSpec(
      label: 'მთავარი',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      branchIndex: 0,
    ),
    _TabSpec(
      label: 'კალენდარი',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      branchIndex: 1,
    ),
    _TabSpec(
      label: 'ისტორია',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      branchIndex: 2,
    ),
    _TabSpec(
      label: 'პარამეტრები',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      branchIndex: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _selectedVisualIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(AppNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync visual index when shell changes externally
    final shellIdx = widget.navigationShell.currentIndex;
    if (_selectedVisualIndex != shellIdx) {
      setState(() => _selectedVisualIndex = shellIdx);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTabTap(int visualIndex) {
    final tab = _tabs[visualIndex];
    if (tab.branchIndex == null) {
      // Stub tab — silent ignore
      return;
    }
    setState(() => _selectedVisualIndex = visualIndex);
    widget.navigationShell.goBranch(
      tab.branchIndex!,
      initialLocation: tab.branchIndex == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTheme.blurMedium,
              sigmaY: AppTheme.blurMedium,
            ),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withAlpha(204),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(color: AppTheme.glassBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(77),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tabs.length, (i) {
                  return _NavTabItem(
                    tab: _tabs[i],
                    isActive: i == _selectedVisualIndex,
                    isStub: _tabs[i].branchIndex == null,
                    onTap: () => _onTabTap(i),
                  );
                }),
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
  final bool isStub;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.tab,
    required this.isActive,
    required this.isStub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isStub ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 16 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary.withAlpha(26)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? tab.activeIcon : tab.icon,
                  key: ValueKey(isActive),
                  color: isActive ? AppTheme.primary : AppTheme.textMuted,
                  size: 22,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: isActive
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          tab.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
