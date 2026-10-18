import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CalendarLegendWidget extends StatelessWidget {
  const CalendarLegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        0,
        AppTheme.spaceM,
        AppTheme.spaceS,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppTheme.spaceM,
        runSpacing: AppTheme.spaceS,
        children: [
          _LegendItem(color: AppTheme.success, label: 'ვიმუშავე'),
          _LegendItem(color: AppTheme.secondary, label: 'ხელფასი მიღებულია'),
          _LegendItem(color: AppTheme.primary, label: 'ნაწილობრივ მიღებულია'),
          _LegendItem(color: AppTheme.errorColor, label: 'არ მიმუშავია'),
          _LegendItem(color: AppTheme.warning, label: 'დაგეგმილი'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withAlpha(179),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
