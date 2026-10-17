import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SalaryMetricStripWidget extends StatelessWidget {
  final double earned;
  final double received;
  final double remaining;

  const SalaryMetricStripWidget({
    super.key,
    required this.earned,
    required this.received,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        AppTheme.spaceM,
        AppTheme.spaceM,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spaceM,
              horizontal: AppTheme.spaceS,
            ),
            decoration: BoxDecoration(
              color: AppTheme.glassBackgroundDeep,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: AppTheme.glassBorder.withAlpha(128)),
            ),
            child: Row(
              children: [
                _MetricCell(
                  label: 'გამომუშ.',
                  value: earned,
                  icon: Icons.work_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
                _Divider(),
                _MetricCell(
                  label: 'მიღებული',
                  value: received,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.primary,
                ),
                _Divider(),
                _MetricCell(
                  label: 'დარჩენილი',
                  value: remaining,
                  icon: Icons.schedule_rounded,
                  color: AppTheme.warning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppTheme.glassBorder);
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            AppTheme.formatGel(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
