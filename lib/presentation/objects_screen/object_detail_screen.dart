import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../core/georgian_date_utils.dart';
import './widgets/create_edit_object_sheet.dart';

class ObjectDetailScreen extends StatefulWidget {
  final String objectId;
  final DataService dataService;
  final VoidCallback? onChanged;

  const ObjectDetailScreen({
    super.key,
    required this.objectId,
    required this.dataService,
    this.onChanged,
  });

  @override
  State<ObjectDetailScreen> createState() => _ObjectDetailScreenState();
}

class _ObjectDetailScreenState extends State<ObjectDetailScreen> {
  WorkObjectModel? _object;
  Map<String, dynamic> _stats = {};
  List<WorkDayModel> _workDays = [];
  List<AdvanceBalance> _advances = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final obj = widget.dataService.getObjectById(widget.objectId);
    if (obj == null) {
      // Object was deleted while this screen was open — pop back safely.
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final stats = widget.dataService.getObjectStats(widget.objectId);
    final advances = widget.dataService.getAdvanceBalancesForObject(
      widget.objectId,
    );
    final days =
        widget.dataService
            .getWorkDaysForObject(widget.objectId)
            .where((d) => d.isWorked)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _object = obj;
      _stats = stats;
      _workDays = days;
      _advances = advances;
    });
  }

  Future<void> _onComplete() async {
    final confirm = await _showConfirmDialog(
      title: 'ობიექტის დასრულება',
      message: 'ობიექტი დასრულებულად მოინიშნოს?',
      confirmLabel: 'დასრულება',
      destructive: false,
    );
    if (confirm != true) return;
    await widget.dataService.completeObject(widget.objectId);
    widget.onChanged?.call();
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ობიექტი დასრულებულად მოინიშნა',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          backgroundColor: AppTheme.surfaceVariantDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onDelete() async {
    if (_object == null) return;
    final workDayCount = widget.dataService.getWorkDayCountForObject(
      widget.objectId,
    );

    // Build a clear warning message if the object has associated work records.
    final String message;
    if (workDayCount > 0) {
      message =
          'ამ ობიექტს აქვს $workDayCount სამუშაო ჩანაწერი.\n\n'
          'ობიექტის წაშლა ამ ჩანაწერებს არ წაშლის — '
          'ისტორია შენარჩუნდება.\n\n'
          'ნამდვილად გსურთ ობიექტის წაშლა?';
    } else {
      message = 'ნამდვილად გსურთ ამ ობიექტის წაშლა?';
    }

    final confirm = await _showConfirmDialog(
      title: 'ობიექტის წაშლა',
      message: message,
      confirmLabel: 'წაშლა',
      destructive: true,
    );
    if (confirm != true) return;
    await widget.dataService.deleteObject(widget.objectId);
    widget.onChanged?.call();
    if (mounted) Navigator.of(context).pop();
  }

  void _onEdit() {
    if (_object == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CreateEditObjectSheet(
        existing: _object,
        onSave: (name, address, note) async {
          final updated = _object!.copyWith(
            name: name,
            address: address,
            note: note,
          );
          await widget.dataService.updateObject(updated);
          if (mounted) Navigator.of(context).pop();
          widget.onChanged?.call();
          _refresh();
        },
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool destructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surfaceVariantDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceL),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.glassBackground,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          border: Border.all(color: AppTheme.glassBorder),
                        ),
                        child: const Text(
                          'გაუქმება',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceS),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: destructive
                              ? AppTheme.errorColor.withAlpha(26)
                              : AppTheme.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          border: Border.all(
                            color: destructive
                                ? AppTheme.errorColor.withAlpha(77)
                                : AppTheme.primary.withAlpha(77),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: destructive
                                ? AppTheme.errorColor
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_object == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final obj = _object!;
    final isActive = obj.status == WorkObjectStatus.active;
    final workedDays = _stats['workedDays'] as int? ?? 0;
    final earned = _stats['earned'] as double? ?? 0;
    final received = _stats['received'] as double? ?? 0;
    final remaining = _stats['remaining'] as double? ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3, -0.6),
                  radius: 1.0,
                  colors: [Color(0xFF0D1F35), AppTheme.backgroundDark],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceM,
                      AppTheme.spaceM,
                      AppTheme.spaceM,
                      0,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.glassBackground,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _onEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.glassBackground,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'რედაქტირება',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Object header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spaceL),
                          decoration: BoxDecoration(
                            color: AppTheme.glassBackground,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusXL,
                            ),
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.primary.withAlpha(51)
                                  : AppTheme.glassBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppTheme.primary.withAlpha(26)
                                          : AppTheme.glassBackground,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                      border: Border.all(
                                        color: isActive
                                            ? AppTheme.primary.withAlpha(51)
                                            : AppTheme.glassBorder,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.domain_rounded,
                                      size: 24,
                                      color: isActive
                                          ? AppTheme.primary
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spaceM),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          obj.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (obj.address.isNotEmpty)
                                          Text(
                                            obj.address,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppTheme.success.withAlpha(26)
                                          : AppTheme.textMuted.withAlpha(26),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull,
                                      ),
                                      border: Border.all(
                                        color: isActive
                                            ? AppTheme.success.withAlpha(77)
                                            : AppTheme.glassBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isActive
                                                ? AppTheme.success
                                                : AppTheme.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isActive ? 'აქტიური' : 'დასრულებული',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isActive
                                                ? AppTheme.success
                                                : AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (obj.note.isNotEmpty) ...[
                                const SizedBox(height: AppTheme.spaceM),
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spaceS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.glassBackgroundDeep,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusS,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.glassBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.notes_rounded,
                                        size: 14,
                                        color: AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          obj.note,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceM,
                      0,
                      AppTheme.spaceM,
                      AppTheme.spaceM,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spaceM),
                          decoration: BoxDecoration(
                            color: AppTheme.glassBackground,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusL,
                            ),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: Row(
                            children: [
                              _StatItem(
                                label: 'სამ. დღეები',
                                value: '$workedDays',
                                icon: Icons.calendar_today_rounded,
                                color: AppTheme.textSecondary,
                              ),
                              _VertDivider(),
                              _StatItem(
                                label: 'გამომუშ.',
                                value: AppTheme.formatGel(earned),
                                icon: Icons.trending_up_rounded,
                                color: AppTheme.success,
                              ),
                              _VertDivider(),
                              _StatItem(
                                label: 'მიღებული',
                                value: AppTheme.formatGel(received),
                                icon: Icons.payments_rounded,
                                color: AppTheme.secondary,
                              ),
                              _VertDivider(),
                              _StatItem(
                                label: 'დარჩენილი',
                                value: AppTheme.formatGel(remaining),
                                icon: Icons.account_balance_wallet_rounded,
                                color: remaining > 0
                                    ? AppTheme.warning
                                    : AppTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_advances.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceM,
                        0,
                        AppTheme.spaceM,
                        AppTheme.spaceM,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spaceM),
                        decoration: BoxDecoration(
                          color: AppTheme.glassBackground,
                          borderRadius: BorderRadius.circular(AppTheme.radiusL),
                          border: Border.all(
                            color: AppTheme.warning.withAlpha(77),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppTheme.warning,
                                  size: 18,
                                ),
                                SizedBox(width: AppTheme.spaceS),
                                Text(
                                  'ამ ობიექტზე აღებული ავანსები',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spaceS),
                            for (final balance in _advances)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppTheme.spaceS,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${GeorgianDateUtils.formatDate(balance.advance.dateTime)} · '
                                        '${AppTheme.formatGel(balance.advance.amount)}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      balance.remaining <= 0.001
                                          ? 'დაფარულია'
                                          : 'დარჩა ${AppTheme.formatGel(balance.remaining)}',
                                      style: TextStyle(
                                        color: balance.remaining <= 0.001
                                            ? AppTheme.success
                                            : AppTheme.warning,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Work history
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceM,
                      0,
                      AppTheme.spaceM,
                      AppTheme.spaceS,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'სამუშაო ისტორია',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_workDays.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spaceL),
                      child: Text(
                        'სამუშაო ჩანაწერები ჯერ არ არის',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final wd = _workDays[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spaceM,
                          0,
                          AppTheme.spaceM,
                          AppTheme.spaceS,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceM,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.glassBackground,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spaceM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      GeorgianDateUtils.formatDate(wd.date),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const Text(
                                      '✓ სამუშაო დღე',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                AppTheme.formatGel(wd.dailyWage),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: _workDays.length),
                  ),
                // Actions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceM,
                      AppTheme.spaceM,
                      AppTheme.spaceM,
                      0,
                    ),
                    child: Column(
                      children: [
                        if (isActive)
                          GestureDetector(
                            onTap: _onComplete,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withAlpha(13),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusM,
                                ),
                                border: Border.all(
                                  color: AppTheme.success.withAlpha(51),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: AppTheme.success,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'ობიექტის დასრულება',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: AppTheme.spaceS),
                        GestureDetector(
                          onTap: _onDelete,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withAlpha(13),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(
                                color: AppTheme.errorColor.withAlpha(51),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: AppTheme.errorColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'ობიექტის წაშლა',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
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
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppTheme.glassBorder,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
