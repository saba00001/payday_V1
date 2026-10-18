import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CalendarLegendWidget extends StatelessWidget {
  const CalendarLegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surfaceElevated.withAlpha(170),
              AppTheme.surfaceDark.withAlpha(150),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            _LegendItem(color: AppTheme.success, label: 'ვიმუშავე'),
            _LegendItem(color: AppTheme.secondary, label: 'ხელფასი მიღებულია'),
            _LegendItem(color: AppTheme.primary, label: 'ნაწილობრივ მიღებულია'),
            _LegendItem(color: AppTheme.errorColor, label: 'არ მიმუშავია'),
            _LegendItem(color: AppTheme.warning, label: 'დაგეგმილი'),
          ],
        ),
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(70), blurRadius: 6)],
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
