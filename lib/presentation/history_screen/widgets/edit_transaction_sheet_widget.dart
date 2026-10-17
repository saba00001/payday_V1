import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_theme.dart';
import '../../../models/payment_transaction_model.dart';

class EditTransactionSheetWidget extends StatefulWidget {
  final PaymentTransactionModel transaction;

  /// The maximum amount this transaction can be edited to.
  /// Must be pre-calculated as: totalRemaining + transaction.amount
  /// (i.e. remaining if this transaction did not exist).
  final double maxAmount;
  final void Function(PaymentTransactionModel) onSave;

  const EditTransactionSheetWidget({
    super.key,
    required this.transaction,
    required this.maxAmount,
    required this.onSave,
  });

  @override
  State<EditTransactionSheetWidget> createState() =>
      _EditTransactionSheetWidgetState();
}

class _EditTransactionSheetWidgetState
    extends State<EditTransactionSheetWidget> {
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  String? _errorText;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.transaction.amount.toInt().toString(),
    );
    _noteCtrl = TextEditingController(text: widget.transaction.note);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _amountCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'შეიყვანეთ თანხა');
      return;
    }
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'არასწორი თანხა');
      return;
    }
    // maxAmount = remaining (without this tx) + this tx's current amount
    // = the maximum this tx can be set to without exceeding total earned.
    // Allow a tiny floating-point tolerance.
    if (amount > widget.maxAmount + 0.001) {
      setState(
        () => _errorText =
            'მაქსიმალური დასაშვები თანხა: ${AppTheme.formatGel(widget.maxAmount)}',
      );
      return;
    }
    setState(() => _errorText = null);
  }

  Future<void> _save() async {
    _validate();
    if (_errorText != null) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 150));
    widget.onSave(
      widget.transaction.copyWith(amount: amount, note: _noteCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                const Text(
                  'ტრანზაქციის რედაქტირება',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceS),
                Row(
                  children: [
                    const Text(
                      'მაქს. დასაშვები: ',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    Text(
                      AppTheme.formatGel(widget.maxAmount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceM),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  onChanged: (_) => _validate(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    labelText: 'თანხა (₾)',
                    labelStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                    suffixText: '₾',
                    suffixStyle: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: AppTheme.glassBackground,
                    errorText: _errorText,
                    errorStyle: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'შენიშვნა (სურვილისამებრ)',
                    hintStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppTheme.glassBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                GestureDetector(
                  onTap: _loading ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(color: AppTheme.primary.withAlpha(77)),
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'შენახვა',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                    ),
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
