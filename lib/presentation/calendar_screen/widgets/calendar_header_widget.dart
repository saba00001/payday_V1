import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/georgian_date_utils.dart';

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
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        AppTheme.spaceM,
        AppTheme.spaceM,
        AppTheme.spaceS,
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentBlue.withAlpha(45),
                      AppTheme.secondary.withAlpha(28),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.accentBlue.withAlpha(64)),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 21,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'კალენდარი',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'სამუშაო დღეები და ანაზღაურება',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.surfaceElevated.withAlpha(225),
                  AppTheme.surfaceDark.withAlpha(225),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    GeorgianDateUtils.formatMonthYear(year, month),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                _NavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: AppTheme.accentBlue,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.accentBlue.withAlpha(18),
        minimumSize: const Size(34, 34),
      ),
    );
  }
}
