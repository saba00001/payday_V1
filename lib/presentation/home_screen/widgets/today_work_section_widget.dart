import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/work_day_model.dart';
import '../../../models/work_object_model.dart';

class TodayWorkSectionWidget extends StatelessWidget {
  final WorkObjectModel? todayObject;
  final WorkDayModel? todayWorkDay;
  final WorkObjectModel? yesterdayObject;
  final double currentDailyWage; // Current applicable wage for today
  final VoidCallback onMarkWorked;
  final VoidCallback onMarkNotWorked;
  final VoidCallback onSelectObject;
  final VoidCallback onChangeObject;
  final VoidCallback onUseYesterdayObject;

  const TodayWorkSectionWidget({
    super.key,
    required this.todayObject,
    required this.todayWorkDay,
    required this.yesterdayObject,
    required this.currentDailyWage,
    required this.onMarkWorked,
    required this.onMarkNotWorked,
    required this.onSelectObject,
    required this.onChangeObject,
    required this.onUseYesterdayObject,
  });

  bool get _workedToday => todayWorkDay?.status == WorkDayStatus.worked;
  bool get _notWorkedToday => todayWorkDay?.status == WorkDayStatus.notWorked;

  /// True only when the object is still active (can be re-selected / changed).
  bool get _isObjectActive =>
      todayObject != null && todayObject!.status == WorkObjectStatus.active;

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
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceM),
            decoration: BoxDecoration(
              color: AppTheme.glassBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.today_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'დღეს',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceM),

                // State machine:
                // A: no object, no worked record, no yesterday hint
                // B: no object, no worked record, yesterday hint available
                // C: object selected, not worked yet
                // D: worked today (object may be active, completed, or deleted)
                // E: not-worked state
                if (_workedToday)
                  // State D: worked today — show result card
                  // Object may be active, completed, or deleted (null)
                  _WorkedTodayState(
                    object: todayObject,
                    workDay: todayWorkDay!,
                    isObjectActive: _isObjectActive,
                    onMarkNotWorked: onMarkNotWorked,
                    onChangeObject: onChangeObject,
                  )
                else if (_notWorkedToday)
                  _NotWorkedState(onRevert: onMarkWorked)
                else if (!_workedToday &&
                    !_notWorkedToday &&
                    todayObject == null &&
                    yesterdayObject != null)
                  _YesterdayHint(
                    object: yesterdayObject!,
                    onUse: onUseYesterdayObject,
                    onOther: onSelectObject,
                  )
                else if (todayObject == null)
                  _NoObjectState(onSelect: onSelectObject)
                else
                  // Object selected, not worked yet — only active objects reach here
                  _ObjectSelectedState(
                    object: todayObject,
                    isWorked: false,
                    dailyWage: currentDailyWage,
                    onMarkWorked: onMarkWorked,
                    onMarkNotWorked: onMarkNotWorked,
                    onChangeObject: onChangeObject,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── State D: Worked today ─────────────────────────────────────────────────────
class _WorkedTodayState extends StatelessWidget {
  final WorkObjectModel? object;
  final WorkDayModel workDay;
  final bool isObjectActive;
  final VoidCallback onMarkNotWorked;
  final VoidCallback onChangeObject;

  const _WorkedTodayState({
    required this.object,
    required this.workDay,
    required this.isObjectActive,
    required this.onMarkNotWorked,
    required this.onChangeObject,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve display name: prefer live object name, fall back to snapshot
    final displayName = object?.name.isNotEmpty == true
        ? object!.name
        : workDay.objectName.isNotEmpty
        ? workDay.objectName
        : 'ობიექტი';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceM),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantDark,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'დღიური: ${AppTheme.formatGel(workDay.dailyWage)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Only show change-object button if the object is still active
              if (isObjectActive)
                GestureDetector(
                  onTap: onChangeObject,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.glassBackground,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: const Text(
                      'შეცვლა',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceM),
        // Worked confirmation badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.success.withAlpha(26),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(color: AppTheme.success.withAlpha(77)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppTheme.success,
              ),
              SizedBox(width: 6),
              Text(
                '✓ ვიმუშავე დღეს',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceS),
        GestureDetector(
          onTap: onMarkNotWorked,
          child: const Center(
            child: Text(
              'გაუქმება',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _YesterdayHint extends StatelessWidget {
  final WorkObjectModel object;
  final VoidCallback onUse;
  final VoidCallback onOther;

  const _YesterdayHint({
    required this.object,
    required this.onUse,
    required this.onOther,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceM),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantDark,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 14,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'გუშინ მუშაობდი აქ',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      object.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceS),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'ისევ ამ ობიექტზე',
                icon: Icons.replay_rounded,
                color: AppTheme.primary,
                onTap: onUse,
              ),
            ),
            const SizedBox(width: AppTheme.spaceS),
            Expanded(
              child: _ActionButton(
                label: 'სხვა ობიექტი',
                icon: Icons.swap_horiz_rounded,
                color: AppTheme.textSecondary,
                onTap: onOther,
                outlined: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NoObjectState extends StatelessWidget {
  final VoidCallback onSelect;

  const _NoObjectState({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'სად ვმუშაობ დღეს?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceM),
        GestureDetector(
          onTap: onSelect,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(13),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: AppTheme.primary.withAlpha(51),
                style: BorderStyle.solid,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text(
                  'აირჩიე ობიექტი',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotWorkedState extends StatelessWidget {
  final VoidCallback onRevert;

  const _NotWorkedState({required this.onRevert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withAlpha(13),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.errorColor.withAlpha(51)),
      ),
      child: Row(
        children: [
          const Icon(Icons.close_rounded, size: 20, color: AppTheme.errorColor),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'დღეს არ მიმუშავია',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRevert,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.glassBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Text(
                'ვიმუშავე',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectSelectedState extends StatelessWidget {
  final WorkObjectModel? object;
  final bool isWorked;
  final double dailyWage;
  final VoidCallback onMarkWorked;
  final VoidCallback onMarkNotWorked;
  final VoidCallback onChangeObject;

  const _ObjectSelectedState({
    required this.object,
    required this.isWorked,
    required this.dailyWage,
    required this.onMarkWorked,
    required this.onMarkNotWorked,
    required this.onChangeObject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Object display
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceM),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantDark,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      object?.name ?? 'ობიექტი',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'დღიური: ${AppTheme.formatGel(dailyWage)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onChangeObject,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.glassBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: const Text(
                    'შეცვლა',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceM),
        // Not worked yet — show action buttons
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'ვიმუშავე',
                icon: Icons.check_rounded,
                color: AppTheme.primary,
                onTap: onMarkWorked,
              ),
            ),
            const SizedBox(width: AppTheme.spaceS),
            Expanded(
              child: _ActionButton(
                label: 'არ მიმუშავია',
                icon: Icons.close_rounded,
                color: AppTheme.errorColor,
                onTap: onMarkNotWorked,
                outlined: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withAlpha(26),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
