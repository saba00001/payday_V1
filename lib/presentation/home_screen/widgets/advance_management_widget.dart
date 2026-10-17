import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../services/data_service.dart';
import '../../../theme/app_theme.dart';

class AdvanceManagementWidget extends StatelessWidget {
  final List<AdvanceBalance> balances;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onDelete;

  const AdvanceManagementWidget({
    super.key,
    required this.balances,
    required this.onAdd,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context, AdvanceBalance balance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariantDark,
        title: const Text('ავანსის წაშლა?'),
        content: const Text(
          'ავანსის წაშლით მასთან холбоებული დაფარვაც გაუქმდება.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('გაუქმება'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('წაშლა'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete(balance.advance.id);
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
            padding: const EdgeInsets.all(AppTheme.spaceM),
            decoration: BoxDecoration(
              color: AppTheme.glassBackgroundDeep,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: AppTheme.glassBorder.withAlpha(128)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppTheme.warning,
                      size: 18,
                    ),
                    const SizedBox(width: AppTheme.spaceS),
                    const Expanded(
                      child: Text(
                        'ავანსები ობიექტების მიხედვით',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (balances.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(
                      top: AppTheme.spaceS,
                      bottom: AppTheme.spaceS,
                    ),
                    child: Text(
                      'ავანსი ჯერ არ არის დამატებული.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...balances.map(
                    (balance) => _AdvanceRow(
                      balance: balance,
                      onDelete: () => _confirmDelete(context, balance),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('ავანსის დამატება'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvanceRow extends StatelessWidget {
  final AdvanceBalance balance;
  final VoidCallback onDelete;

  const _AdvanceRow({required this.balance, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final paidProgress = balance.advance.amount <= 0
        ? 0.0
        : (balance.repaid / balance.advance.amount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceS),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceS),
        decoration: BoxDecoration(
          color: AppTheme.glassBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    balance.advance.objectName.isEmpty
                        ? 'წაშლილი ობიექტი'
                        : balance.advance.objectName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'ავანსის წაშლა',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            Text(
              'დაფარულია ${AppTheme.formatGel(balance.repaid)} / '
              '${AppTheme.formatGel(balance.advance.amount)}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: LinearProgressIndicator(
                value: paidProgress,
                minHeight: 5,
                backgroundColor: AppTheme.glassBorder,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              balance.remaining <= 0.001
                  ? 'დაფარულია სრულად'
                  : 'დარჩენილია ${AppTheme.formatGel(balance.remaining)}',
              style: TextStyle(
                color: balance.remaining <= 0.001
                    ? AppTheme.secondary
                    : AppTheme.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
