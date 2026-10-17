import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/georgian_date_utils.dart';
import '../../../models/payment_transaction_model.dart';
import '../../../widgets/empty_state_widget.dart';

class HistoryTransactionsSectionWidget extends StatelessWidget {
  final List<PaymentTransactionModel> transactions;
  final void Function(PaymentTransactionModel) onEdit;
  final void Function(String) onDelete;

  const HistoryTransactionsSectionWidget({
    super.key,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

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
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 14,
                color: AppTheme.secondary,
              ),
              const SizedBox(width: 6),
              const Text(
                'ტრანზაქციები',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceM),
          if (transactions.isEmpty)
            EmptyStateWidget(
              icon: Icons.receipt_outlined,
              title: 'გადახდები ჯერ არ არის',
              subtitle: 'გადახდის დასამატებლად გამოიყენე მთავარი გვერდი',
            )
          else
            ...transactions.map(
              (tx) => _TransactionRow(
                transaction: tx,
                onEdit: () => onEdit(tx),
                onDelete: () => onDelete(tx.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final PaymentTransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionRow({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('tx_${transaction.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceS),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withAlpha(26),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.errorColor.withAlpha(51)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spaceM),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.errorColor,
          size: 20,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion ourselves
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceS),
        padding: const EdgeInsets.all(AppTheme.spaceM),
        decoration: BoxDecoration(
          color: AppTheme.glassBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.secondary.withAlpha(51)),
        ),
        child: Row(
          children: [
            // Circle icon — anatomy locked from reference image
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withAlpha(26),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.secondary.withAlpha(51)),
              ),
              child: const Icon(
                Icons.payments_rounded,
                size: 18,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceM),
            // Name + subtitle — anatomy locked
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'გადახდა',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    transaction.objectName.isNotEmpty
                        ? transaction.objectName
                        : GeorgianDateUtils.formatDateTime(
                            transaction.dateTime,
                          ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Amount + time right — anatomy locked
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${AppTheme.formatGel(transaction.amount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  GeorgianDateUtils.formatTime(transaction.dateTime),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppTheme.spaceS),
            // Edit button
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.glassBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
