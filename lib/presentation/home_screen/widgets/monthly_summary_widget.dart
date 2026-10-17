import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/georgian_date_utils.dart';
import '../../../services/data_service.dart';

class MonthlySummaryWidget extends StatefulWidget {
  final DataService dataService;

  const MonthlySummaryWidget({super.key, required this.dataService});

  @override
  State<MonthlySummaryWidget> createState() => _MonthlySummaryWidgetState();
}

class _MonthlySummaryWidgetState extends State<MonthlySummaryWidget> {
  late int _year;
  late int _month;
  late MonthlySummaryData _summary;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    // Always load fresh data on init (ValueKey in parent forces rebuild on refresh)
    _summary = widget.dataService.getMonthlySummary(_year, _month);
  }

  @override
  void didUpdateWidget(MonthlySummaryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload whenever the widget is updated (e.g. after payment add/delete)
    _reload();
  }

  void _reload() {
    setState(() {
      _summary = widget.dataService.getMonthlySummary(_year, _month);
    });
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
      _summary = widget.dataService.getMonthlySummary(_year, _month);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    // Don't navigate past current month
    if (_year > now.year || (_year == now.year && _month >= now.month)) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
      _summary = widget.dataService.getMonthlySummary(_year, _month);
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

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
            decoration: BoxDecoration(
              color: AppTheme.glassBackgroundDeep,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: AppTheme.glassBorder.withAlpha(128)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_summary.isEmpty)
                  _buildEmptyState()
                else ...[
                  _buildMetricsGrid(),
                  if (_summary.objectBreakdown.isNotEmpty) ...[
                    _buildSectionDivider(),
                    _buildObjectBreakdown(),
                  ],
                  if (_summary.payments.isNotEmpty) ...[
                    _buildSectionDivider(),
                    _buildPaymentBreakdown(),
                  ],
                  const SizedBox(height: AppTheme.spaceM),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final monthLabel = GeorgianDateUtils.formatMonthYear(_year, _month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        AppTheme.spaceM,
        AppTheme.spaceS,
        AppTheme.spaceM,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withAlpha(26),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(width: AppTheme.spaceS),
          const Text(
            'თვის შეჯამება',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          // Month selector
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: _isCurrentMonth ? null : _nextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        0,
        AppTheme.spaceM,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'ნამუშევარი დღეები',
                  value: '${_summary.workedDays} დღე',
                  icon: Icons.work_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceS),
              Expanded(
                child: _MetricTile(
                  label: 'გამომუშავებული',
                  value: AppTheme.formatGel(_summary.earned),
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceS),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'მიღებული',
                  value: AppTheme.formatGel(_summary.received),
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceS),
              Expanded(
                child: _MetricTile(
                  label: 'დარჩენილი',
                  value: AppTheme.formatGel(_summary.remaining),
                  icon: Icons.schedule_rounded,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          if (_summary.advanceRepaid > 0) ...[
            const SizedBox(height: AppTheme.spaceS),
            _MetricTile(
              label: 'ავანსით დაფარული',
              value: AppTheme.formatGel(_summary.advanceRepaid),
              icon: Icons.account_balance_wallet_outlined,
              color: AppTheme.warning,
              fullWidth: true,
            ),
          ],
          if (_summary.paymentCount > 0) ...[
            const SizedBox(height: AppTheme.spaceS),
            _MetricTile(
              label: 'გადახდები',
              value: '${_summary.paymentCount}',
              icon: Icons.payments_outlined,
              color: AppTheme.primary,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceM,
        vertical: AppTheme.spaceS,
      ),
      child: Container(height: 1, color: AppTheme.glassBorder.withAlpha(77)),
    );
  }

  Widget _buildObjectBreakdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        0,
        AppTheme.spaceM,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ობიექტების მიხედვით',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),
          ..._summary.objectBreakdown.map((obj) => _ObjectRow(summary: obj)),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        0,
        AppTheme.spaceM,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'გადახდები',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),
          ..._summary.payments
              .take(5)
              .map((tx) => _PaymentRow(transaction: tx)),
          if (_summary.payments.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ კიდევ ${_summary.payments.length - 5} გადახდა',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        0,
        AppTheme.spaceM,
        AppTheme.spaceL,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.glassBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 20,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),
          const Text(
            'ამ თვეში ჯერ სამუშაო მონაცემები არ არის.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.glassBackground
              : AppTheme.glassBackground.withAlpha(77),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border: Border.all(
            color: enabled
                ? AppTheme.glassBorder
                : AppTheme.glassBorder.withAlpha(77),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppTheme.textSecondary : AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceM,
        vertical: AppTheme.spaceS + 2,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withAlpha(38)),
      ),
      child: fullWidth
          ? Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: AppTheme.spaceS),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withAlpha(179),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 12, color: color.withAlpha(179)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withAlpha(179),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }
}

class _ObjectRow extends StatelessWidget {
  final ObjectMonthlySummary summary;

  const _ObjectRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceS),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: summary.isDeleted ? AppTheme.textMuted : AppTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spaceS),
          Expanded(
            child: Text(
              summary.objectName.isNotEmpty ? summary.objectName : 'ობიექტი',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: summary.isDeleted
                    ? AppTheme.textMuted
                    : AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppTheme.spaceS),
          Text(
            '${summary.workedDays} დღე · ${AppTheme.formatGel(summary.earned)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final dynamic transaction;

  const _PaymentRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dt = transaction.dateTime as DateTime;
    final dateStr = GeorgianDateUtils.formatDate(dt);
    final objectName = transaction.objectName as String;
    final note = transaction.note as String;
    final amount = transaction.amount as double;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: AppTheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spaceS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (objectName.isNotEmpty) ...[
                      const Text(
                        ' · ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          objectName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Text(
                      AppTheme.formatGel(amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
