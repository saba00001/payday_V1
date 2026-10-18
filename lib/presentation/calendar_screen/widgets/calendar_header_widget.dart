import 'package:flutter/material.dart';

import '../../../core/georgian_date_utils.dart';
import '../../../theme/app_theme.dart';

class CalendarHeaderWidget extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const CalendarHeaderWidget({
    super.key,
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentBlue.withAlpha(48),
                      AppTheme.secondary.withAlpha(35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentBlue.withAlpha(74)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentBlue.withAlpha(18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 22,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'კალენდარი',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.45,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'სამუშაო დღეები და ანაზღაურება',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surfaceElevated.withAlpha(220),
                  AppTheme.surfaceDark.withAlpha(238),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentBlue.withAlpha(12),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavButton(
                  tooltip: 'წინა თვე',
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrev,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      GeorgianDateUtils.formatMonthYear(year, month),
                      key: ValueKey((year, month)),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                _NavButton(
                  tooltip: 'შემდეგი თვე',
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 23),
      color: AppTheme.accentBlue,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.accentBlue.withAlpha(22),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
