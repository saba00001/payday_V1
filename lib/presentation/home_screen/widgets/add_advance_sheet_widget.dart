import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/work_object_model.dart';
import '../../../theme/app_theme.dart';

class AddAdvanceSheetWidget extends StatefulWidget {
  final List<WorkObjectModel> objects;
  final Future<bool> Function(double amount, String objectId) onAdd;

  const AddAdvanceSheetWidget({
    super.key,
    required this.objects,
    required this.onAdd,
  });

  @override
  State<AddAdvanceSheetWidget> createState() => _AddAdvanceSheetWidgetState();
}

class _AddAdvanceSheetWidgetState extends State<AddAdvanceSheetWidget> {
  final _amountController = TextEditingController();
  String? _selectedObjectId;
  String? _errorText;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedObjectId = widget.objects.isEmpty ? null : widget.objects.first.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'შეიყვანეთ სწორი თანხა');
      return;
    }
    final objectId = _selectedObjectId;
    if (objectId == null) {
      setState(() => _errorText = 'აირჩიეთ ობიექტი');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });
    final added = await widget.onAdd(amount, objectId);
    if (!mounted) return;
    if (added) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _loading = false;
        _errorText = 'ავანსის შენახვა ვერ მოხერხდა';
      });
    }
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
                  'ავანსის დამატება',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceS),
                const Text(
                  'ავანსი დაიფარება მხოლოდ არჩეულ ობიექტზე შემდეგი ნამუშევარი დღეებით.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                DropdownButtonFormField<String>(
                  initialValue: _selectedObjectId,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceDark,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'ობიექტი',
                    labelStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.glassBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                  items: widget.objects
                      .map(
                        (object) => DropdownMenuItem(
                          value: object.id,
                          child: Text(
                            object.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (objectId) =>
                            setState(() => _selectedObjectId = objectId),
                ),
                const SizedBox(height: AppTheme.spaceM),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    labelText: 'თანხა (₾)',
                    labelStyle: const TextStyle(color: AppTheme.textMuted),
                    suffixText: '₾',
                    suffixStyle: const TextStyle(color: AppTheme.primary),
                    errorText: _errorText,
                    filled: true,
                    fillColor: AppTheme.glassBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading || widget.objects.isEmpty
                        ? null
                        : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ავანსის შენახვა'),
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
