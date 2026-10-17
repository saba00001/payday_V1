import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import './widgets/edit_transaction_sheet_widget.dart';
import './widgets/history_background_widget.dart';
import './widgets/history_header_widget.dart';
import './widgets/history_object_filter_widget.dart';
import './widgets/history_transactions_section_widget.dart';
import './widgets/history_work_section_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  // TODO: Replace with Riverpod/Bloc for production
  final _dataService = DataService(LocalStorageService());
  bool _initialized = false;

  String? _filterObjectId; // null = all
  List<WorkDayModel> _workDays = [];
  List<PaymentTransactionModel> _transactions = [];
  List<WorkObjectModel> _objects = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    DataService.dataRevision.addListener(_onDataRestored);
    _init();
  }

  @override
  void dispose() {
    DataService.dataRevision.removeListener(_onDataRestored);
    super.dispose();
  }

  Future<void> _onDataRestored() async {
    await _dataService.reloadFromStorage();
    _refresh();
  }

  Future<void> _init() async {
    await _dataService.init();
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _initialized = true;
      _objects = _dataService.objects;
      _workDays = _filterObjectId == null
          ? List.from(_dataService.workDays)
          : _dataService.getWorkDaysForObject(_filterObjectId!).toList();
      _transactions = _filterObjectId == null
          ? List.from(_dataService.transactions)
          : _dataService.transactions
                .where((t) => t.objectId == _filterObjectId)
                .toList();

      // Sort descending
      _workDays.sort((a, b) => b.date.compareTo(a.date));
      _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    });
  }

  void _setFilter(String? objectId) {
    setState(() => _filterObjectId = objectId);
    _refresh();
  }

  Future<void> _deleteTransaction(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'ტრანზაქციის წაშლა',
        message: 'გსურთ ამ გადახდის წაშლა?',
        confirmLabel: 'წაშლა',
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
        destructive: true,
      ),
    );
    if (confirm == true) {
      await _dataService.deleteTransaction(id);
      _refresh();
    }
  }

  void _editTransaction(PaymentTransactionModel tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EditTransactionSheetWidget(
        transaction: tx,
        maxAmount: _dataService.getTotalSalary()['remaining']! + tx.amount,
        onSave: (updated) async {
          await _dataService.updateTransaction(updated);
          Navigator.of(context).pop();
          _refresh();
        },
      ),
    );
  }

  // Group work days by year+month — key format: "YYYY-MM" (already includes year)
  Map<String, List<WorkDayModel>> _groupWorkDays() {
    final map = <String, List<WorkDayModel>>{};
    for (final wd in _workDays) {
      final key = '${wd.date.year}-${wd.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(wd);
    }
    // Sort keys descending (most recent first)
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const HistoryBackgroundWidget(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spaceM),
                  child: Row(
                    children: [
                      const Expanded(child: HistoryHeaderWidget()),
                      GestureDetector(
                        onTap: () => context
                            .push(AppRoutes.objectsScreen)
                            .then((_) => _refresh()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
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
                                Icons.domain_rounded,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ობიექტები',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                if (_initialized) ...[
                  HistoryObjectFilterWidget(
                    objects: _objects,
                    selectedObjectId: _filterObjectId,
                    onFilter: _setFilter,
                  ),
                ],
                Expanded(
                  child: !_initialized
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceDark,
                          onRefresh: () async => _refresh(),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              // Work days section
                              SliverToBoxAdapter(
                                child: HistoryWorkSectionWidget(
                                  groupedWorkDays: _groupWorkDays(),
                                ),
                              ),
                              // Transactions section
                              SliverToBoxAdapter(
                                child: HistoryTransactionsSectionWidget(
                                  transactions: _transactions,
                                  onEdit: _editTransaction,
                                  onDelete: _deleteTransaction,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 120),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool destructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor = destructive ? AppTheme.errorColor : AppTheme.primary;
    return Dialog(
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
                    onTap: onCancel,
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
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: confirmColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(color: confirmColor.withAlpha(77)),
                      ),
                      child: Text(
                        confirmLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: confirmColor,
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
    );
  }
}
