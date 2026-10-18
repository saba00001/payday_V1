import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/georgian_date_utils.dart';
import '../../../models/work_day_model.dart';

class CalendarGridWidget extends StatelessWidget {
  final int year;
  final int month;
  final List<WorkDayModel> workDays;
  final List<int> workSchedule;
  final Map<String, double> salaryPaymentProgress;
  final void Function(DateTime) onDayTap;

  const CalendarGridWidget({
    super.key,
    required this.year,
    required this.month,
    required this.workDays,
    required this.workSchedule,
    this.salaryPaymentProgress = const {},
    required this.onDayTap,
  });

  WorkDayModel? _getWorkDay(int day) {
    try {
      return workDays.firstWhere((d) => d.date.day == day);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    // weekday: 1=Mon, 7=Sun. We display Mon first.
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final isCurrentMonth = today.year == year && today.month == month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: GeorgianDateUtils.weekdaysShort
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppTheme.spaceS),
          // Grid
          Container(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surfaceElevated.withAlpha(160),
                  AppTheme.surfaceDark.withAlpha(190),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentBlue.withAlpha(12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.92,
                mainAxisSpacing: 6,
                crossAxisSpacing: 5,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (_, index) {
                if (index < startOffset) return const SizedBox.shrink();
                final day = index - startOffset + 1;
                final date = DateTime(year, month, day);
                final workDay = _getWorkDay(day);
                final isToday = isCurrentMonth && today.day == day;
                final isScheduled = workSchedule.contains(date.weekday);

                return _DayCell(
                  day: day,
                  workDay: workDay,
                  isToday: isToday,
                  isScheduled: isScheduled,
                  salaryPaymentProgress:
                      salaryPaymentProgress[workDay?.id] ?? 0,
                  onTap: () => onDayTap(date),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final WorkDayModel? workDay;
  final bool isToday;
  final bool isScheduled;
  final double salaryPaymentProgress;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.workDay,
    required this.isToday,
    required this.isScheduled,
    required this.salaryPaymentProgress,
    required this.onTap,
  });

  Color get _bgColor {
    if (salaryPaymentProgress >= 0.999) {
      return AppTheme.secondary.withAlpha(48);
    }
    if (salaryPaymentProgress > 0) {
      return AppTheme.primary.withAlpha(26);
    }
    if (workDay?.status == WorkDayStatus.worked) {
      return AppTheme.success.withAlpha(44);
    }
    if (workDay?.status == WorkDayStatus.notWorked) {
      return AppTheme.errorColor.withAlpha(32);
    }
    if (isScheduled && workDay == null) {
      return AppTheme.warning.withAlpha(13);
    }
    return Colors.transparent;
  }

  Color get _borderColor {
    if (isToday) return AppTheme.primary;
    if (salaryPaymentProgress >= 0.999) {
      return AppTheme.secondary.withAlpha(102);
    }
    if (salaryPaymentProgress > 0) return AppTheme.primary.withAlpha(77);
    if (workDay?.status == WorkDayStatus.worked) {
      return AppTheme.success.withAlpha(102);
    }
    if (workDay?.status == WorkDayStatus.notWorked) {
      return AppTheme.errorColor.withAlpha(51);
    }
    if (isScheduled && workDay == null) {
      return AppTheme.warning.withAlpha(51);
    }
    return AppTheme.glassBorder.withAlpha(77);
  }

  Color get _textColor {
    if (isToday) return AppTheme.primary;
    if (salaryPaymentProgress >= 0.999) return AppTheme.secondary;
    if (salaryPaymentProgress > 0) return AppTheme.primary;
    if (workDay?.status == WorkDayStatus.worked) return AppTheme.success;
    if (workDay?.status == WorkDayStatus.notWorked) {
      return AppTheme.errorColor;
    }
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _borderColor, width: isToday ? 1.5 : 1),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(51),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: _textColor,
              ),
            ),
            if (salaryPaymentProgress > 0)
              Positioned(
                bottom: 3,
                child: Icon(
                  salaryPaymentProgress >= 0.999
                      ? Icons.check_circle
                      : Icons.circle,
                  size: 7,
                  color: salaryPaymentProgress >= 0.999
                      ? AppTheme.secondary
                      : AppTheme.primary,
                ),
              )
            else if (workDay?.status == WorkDayStatus.worked)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (workDay?.status == WorkDayStatus.notWorked)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
