import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/georgian_date_utils.dart';
import '../../../models/work_day_model.dart';
import '../../../models/work_object_model.dart';
import '../../../widgets/status_badge_widget.dart';

class DayDetailSheetWidget extends StatefulWidget {
  final DateTime date;
  final WorkDayModel? workDay;
  final List<WorkObjectModel> objects;
  final double dailyWage;
  final void Function(String objectId, String objectName, String note)
  onMarkWorked;
  final VoidCallback onMarkNotWorked;
  final void Function(String note) onUpdateNote;

  const DayDetailSheetWidget({
    super.key,
    required this.date,
    required this.workDay,
    required this.objects,
    required this.dailyWage,
    required this.onMarkWorked,
    required this.onMarkNotWorked,
    required this.onUpdateNote,
  });

  @override
  State<DayDetailSheetWidget> createState() => _DayDetailSheetWidgetState();
}

class _DayDetailSheetWidgetState extends State<DayDetailSheetWidget> {
  WorkObjectModel? _selectedObject;
  final _noteCtrl = TextEditingController();
  bool _showNoteField = false;

  @override
  void initState() {
    super.initState();
    if (widget.workDay != null) {
      _noteCtrl.text = widget.workDay!.note;
      if (widget.workDay!.objectId.isNotEmpty) {
        try {
          _selectedObject = widget.objects.firstWhere(
            (o) => o.id == widget.workDay!.objectId,
          );
        } catch (_) {}
      }
    }
    _showNoteField = widget.workDay?.note.isNotEmpty == true;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    return dateOnly.isAfter(today);
  }

  bool get _isToday => GeorgianDateUtils.isToday(widget.date);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateLabel = GeorgianDateUtils.formatDate(widget.date);
    final isWorked = widget.workDay?.status == WorkDayStatus.worked;
    final isNotWorked = widget.workDay?.status == WorkDayStatus.notWorked;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusXL),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL),
            ),
            border: Border(
              top: BorderSide(color: AppTheme.glassBorder),
              left: BorderSide(color: AppTheme.glassBorder),
              right: BorderSide(color: AppTheme.glassBorder),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            AppTheme.spaceM,
            AppTheme.spaceM,
            AppTheme.spaceM,
            AppTheme.spaceM + bottomInset,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Header row
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_isToday)
                            const Text(
                              'დღეს',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (widget.workDay != null)
                        StatusBadgeWidget(status: widget.workDay!.status),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Info strip
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    decoration: BoxDecoration(
                      color: AppTheme.glassBackground,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'ობიექტი',
                          value: widget.workDay?.objectName.isNotEmpty == true
                              ? widget.workDay!.objectName
                              : '—',
                          icon: Icons.construction_rounded,
                        ),
                        const SizedBox(height: AppTheme.spaceS),
                        _InfoRow(
                          label: 'დღიური',
                          // For worked days, show the historical wage stored in the WorkDay
                          // (not the current period wage) to preserve historical accuracy.
                          // For unworked/future days, show the current applicable wage.
                          value: AppTheme.formatGel(
                            isWorked
                                ? (widget.workDay?.dailyWage ??
                                      widget.dailyWage)
                                : widget.dailyWage,
                          ),
                          icon: Icons.attach_money_rounded,
                          valueColor: AppTheme.primary,
                        ),
                        if (isWorked) ...[
                          const SizedBox(height: AppTheme.spaceS),
                          _InfoRow(
                            label: 'გამომუშავებული',
                            value: AppTheme.formatGel(
                              widget.workDay?.dailyWage ?? widget.dailyWage,
                            ),
                            icon: Icons.check_circle_outline_rounded,
                            valueColor: AppTheme.success,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Object selector (if not worked yet and not future)
                  if (!isWorked && !isNotWorked && !_isFuture) ...[
                    const SizedBox(height: AppTheme.spaceM),
                    const Text(
                      'ობიექტის არჩევა',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: AppTheme.spaceS),
                    if (widget.objects.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceM,
                          vertical: AppTheme.spaceS,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.glassBackground,
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(color: AppTheme.glassBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'აქტიური ობიექტები არ არის',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: widget.objects
                              .map(
                                (obj) => GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedObject = obj),
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      right: AppTheme.spaceS,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedObject?.id == obj.id
                                          ? AppTheme.primary.withAlpha(26)
                                          : AppTheme.glassBackground,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull,
                                      ),
                                      border: Border.all(
                                        color: _selectedObject?.id == obj.id
                                            ? AppTheme.primary.withAlpha(77)
                                            : AppTheme.glassBorder,
                                      ),
                                    ),
                                    child: Text(
                                      obj.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedObject?.id == obj.id
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],

                  // Note section
                  if (isWorked || (!isNotWorked && !_isFuture)) ...[
                    const SizedBox(height: AppTheme.spaceM),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showNoteField = !_showNoteField),
                      child: Row(
                        children: [
                          Icon(
                            _showNoteField
                                ? Icons.note_rounded
                                : Icons.note_add_outlined,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showNoteField
                                ? 'შენიშვნა'
                                : '+ შენიშვნის დამატება',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showNoteField) ...[
                      const SizedBox(height: AppTheme.spaceS),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'შენიშვნა...',
                          hintStyle: const TextStyle(color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.glassBackground,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                            borderSide: const BorderSide(
                              color: AppTheme.glassBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                            borderSide: const BorderSide(
                              color: AppTheme.glassBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: AppTheme.spaceM),

                  // Action buttons
                  if (!_isFuture) ...[
                    if (!isWorked && !isNotWorked) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _SheetButton(
                              label: 'ვიმუშავე',
                              icon: Icons.check_rounded,
                              color: AppTheme.success,
                              onTap: () {
                                widget.onMarkWorked(
                                  _selectedObject?.id ?? '',
                                  _selectedObject?.name ?? '',
                                  _noteCtrl.text,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceS),
                          Expanded(
                            child: _SheetButton(
                              label: 'არ მიმუშავია',
                              icon: Icons.close_rounded,
                              color: AppTheme.errorColor,
                              outlined: true,
                              onTap: widget.onMarkNotWorked,
                            ),
                          ),
                        ],
                      ),
                    ] else if (isWorked && _showNoteField) ...[
                      _SheetButton(
                        label: 'შენიშვნის შენახვა',
                        icon: Icons.save_rounded,
                        color: AppTheme.primary,
                        onTap: () => widget.onUpdateNote(_noteCtrl.text),
                        fullWidth: true,
                      ),
                    ] else if (isNotWorked) ...[
                      _SheetButton(
                        label: 'ვიმუშავე (შეცვლა)',
                        icon: Icons.edit_rounded,
                        color: AppTheme.primary,
                        onTap: () {
                          widget.onMarkWorked(
                            _selectedObject?.id ?? '',
                            _selectedObject?.name ?? '',
                            _noteCtrl.text,
                          );
                        },
                        fullWidth: true,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  final bool fullWidth;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
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
    return btn;
  }
}
