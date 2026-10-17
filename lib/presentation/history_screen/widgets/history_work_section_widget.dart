import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/georgian_date_utils.dart';
import '../../../models/work_day_model.dart';
import '../../../widgets/status_badge_widget.dart';
import '../../../widgets/empty_state_widget.dart';

class HistoryWorkSectionWidget extends StatelessWidget {
  final Map<String, List<WorkDayModel>> groupedWorkDays;

  const HistoryWorkSectionWidget({super.key, required this.groupedWorkDays});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        AppTheme.spaceM,
        AppTheme.spaceM,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              const Icon(
                Icons.work_history_rounded,
                size: 14,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'სამუშაო დღეები',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceM),
          if (groupedWorkDays.isEmpty)
            EmptyStateWidget(
              icon: Icons.work_off_outlined,
              title: 'სამუშაო დღეები ჯერ არ დაფიქსირებულა',
              subtitle: 'მთავარ გვერდზე მონიშნე სამუშაო დღე',
            )
          else
            ...groupedWorkDays.entries.map((entry) {
              final parts = entry.key.split('-');
              final year = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final days = entry.value;
              final worked = days.where((d) => d.isWorked).toList();
              final totalEarned = worked.fold<double>(
                0,
                (s, d) => s + d.dailyWage,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month group header
                  _MonthGroupHeader(
                    year: year,
                    month: month,
                    workedDays: worked.length,
                    totalEarned: totalEarned,
                  ),
                  const SizedBox(height: AppTheme.spaceS),
                  ...days.map((wd) => _WorkDayRow(workDay: wd)),
                  const SizedBox(height: AppTheme.spaceM),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _MonthGroupHeader extends StatelessWidget {
  final int year;
  final int month;
  final int workedDays;
  final double totalEarned;

  const _MonthGroupHeader({
    required this.year,
    required this.month,
    required this.workedDays,
    required this.totalEarned,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    // Show year suffix only when it differs from the current year
    final monthLabel = GeorgianDateUtils.formatMonthYear(
      year,
      month,
    ).toUpperCase();
    final yearSuffix = year != currentYear ? ' $year' : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceM,
        vertical: AppTheme.spaceS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        children: [
          // Dot indicator
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$monthLabel$yearSuffix',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            '$workedDays დღე • ${AppTheme.formatGel(totalEarned)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkDayRow extends StatelessWidget {
  final WorkDayModel workDay;

  const _WorkDayRow({required this.workDay});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceS),
      padding: const EdgeInsets.all(AppTheme.spaceM),
      decoration: BoxDecoration(
        color: AppTheme.glassBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: workDay.isWorked
              ? AppTheme.success.withAlpha(51)
              : AppTheme.glassBorder,
        ),
      ),
      child: Row(
        children: [
          // Status indicator left border
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: workDay.isWorked
                  ? AppTheme.success
                  : workDay.status == WorkDayStatus.notWorked
                  ? AppTheme.errorColor
                  : AppTheme.textMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
          ),
          const SizedBox(width: AppTheme.spaceM),
          // Object icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: workDay.isWorked
                  ? AppTheme.success.withAlpha(26)
                  : AppTheme.glassBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(
              Icons.construction_rounded,
              size: 16,
              color: workDay.isWorked ? AppTheme.success : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: AppTheme.spaceM),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GeorgianDateUtils.formatDate(workDay.date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (workDay.objectName.isNotEmpty)
                  Text(
                    workDay.objectName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Right side
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (workDay.isWorked)
                Text(
                  '+${AppTheme.formatGel(workDay.dailyWage)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 2),
              StatusBadgeWidget(status: workDay.status, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
