import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/work_day_model.dart';

class StatusBadgeWidget extends StatelessWidget {
  final WorkDayStatus status;
  final bool compact;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: compact ? 10 : 12, color: config.textColor),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: config.textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getConfig(WorkDayStatus s) {
    switch (s) {
      case WorkDayStatus.worked:
        return _BadgeConfig(
          label: 'ვიმუშავე',
          icon: Icons.check_rounded,
          bgColor: AppTheme.success.withAlpha(26),
          borderColor: AppTheme.success.withAlpha(77),
          textColor: AppTheme.success,
        );
      case WorkDayStatus.notWorked:
        return _BadgeConfig(
          label: 'არ მიმუშავია',
          icon: Icons.close_rounded,
          bgColor: AppTheme.errorColor.withAlpha(26),
          borderColor: AppTheme.errorColor.withAlpha(77),
          textColor: AppTheme.errorColor,
        );
      case WorkDayStatus.scheduled:
        return _BadgeConfig(
          label: 'დაგეგმილი',
          icon: Icons.schedule_rounded,
          bgColor: AppTheme.warning.withAlpha(26),
          borderColor: AppTheme.warning.withAlpha(77),
          textColor: AppTheme.warning,
        );
      default:
        return _BadgeConfig(
          label: 'მოუნიშნავი',
          icon: Icons.remove_rounded,
          bgColor: AppTheme.textMuted.withAlpha(26),
          borderColor: AppTheme.textMuted.withAlpha(77),
          textColor: AppTheme.textMuted,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  _BadgeConfig({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });
}
