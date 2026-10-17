import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/work_object_model.dart';
import '../../../theme/app_theme.dart';

class AddPaymentSheetWidget extends StatefulWidget {
  final double remaining;
  final List<WorkObjectModel> objects;
  final void Function(double amount, String objectId, String objectName) onAdd;

  const AddPaymentSheetWidget({
    super.key,
    required this.remaining,
    required this.objects,
    required this.onAdd,
  });

  @override
  State<AddPaymentSheetWidget> createState() => _AddPaymentSheetWidgetState();
}

class _AddPaymentSheetWidgetState extends State<AddPaymentSheetWidget> {
  final _amountCtrl = TextEditingController();
  String? _errorText;
  WorkObjectModel? _selectedObject;
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
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
    // Use same tolerance as DataService.addTransaction() (0.001) to ensure
    // UI validation matches service-layer validation exactly.
    if (amount > widget.remaining + 0.001) {
      setState(
        () => _errorText =
            'გადასახდელი დარჩენილი თანხა ${AppTheme.formatGel(widget.remaining)}-ია.',
      );
      return;
    }
    setState(() => _errorText = null);
  }

  Future<void> _submit() async {
    _validate();
    if (_errorText != null) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 200));
    widget.onAdd(
      amount,
      _selectedObject?.id ?? '',
      _selectedObject?.name ?? '',
    );
    if (mounted) Navigator.of(context).pop();
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
                  'გადახდის დამატება',
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
                      'დარჩენილი: ',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    Text(
                      AppTheme.formatGel(widget.remaining),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceM),
                // Amount field
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
                if (widget.objects.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceM),
                  const Text(
                    'ობიექტი (სურვილისამებრ)',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: AppTheme.spaceS),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _ObjectChip(
                          label: 'ყველა',
                          selected: _selectedObject == null,
                          onTap: () => setState(() => _selectedObject = null),
                        ),
                        ...widget.objects.map(
                          (obj) => _ObjectChip(
                            label: obj.name,
                            selected: _selectedObject?.id == obj.id,
                            onTap: () => setState(() => _selectedObject = obj),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceM),
                GestureDetector(
                  onTap: _loading ? null : _submit,
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
                              'გადახდის დამატება',
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

class _ObjectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ObjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: AppTheme.spaceS),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withAlpha(26)
              : AppTheme.glassBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withAlpha(77)
                : AppTheme.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
