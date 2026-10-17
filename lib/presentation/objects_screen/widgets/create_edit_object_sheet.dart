import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/work_object_model.dart';

class CreateEditObjectSheet extends StatefulWidget {
  final WorkObjectModel? existing;
  final Future<void> Function(String name, String address, String note) onSave;

  const CreateEditObjectSheet({super.key, this.existing, required this.onSave});

  @override
  State<CreateEditObjectSheet> createState() => _CreateEditObjectSheetState();
}

class _CreateEditObjectSheetState extends State<CreateEditObjectSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _noteCtrl;
  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'სახელი სავალდებულოა');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    await widget.onSave(name, _addressCtrl.text.trim(), _noteCtrl.text.trim());
    if (mounted) setState(() => _saving = false);
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
                  Row(
                    children: [
                      Icon(
                        _isEdit
                            ? Icons.edit_rounded
                            : Icons.add_business_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEdit ? 'ობიექტის რედაქტირება' : '+ ახალი ობიექტი',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceL),
                  // Name field
                  _FieldLabel(label: 'ობიექტის სახელი', required: true),
                  const SizedBox(height: AppTheme.spaceS),
                  _GlassTextField(
                    controller: _nameCtrl,
                    hint: 'მაგ. ვაჟა-ფშაველას 72',
                    error: _nameError,
                    autofocus: !_isEdit,
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Address field
                  _FieldLabel(label: 'მისამართი', required: false),
                  const SizedBox(height: AppTheme.spaceS),
                  _GlassTextField(
                    controller: _addressCtrl,
                    hint: 'სურვილისამებრ',
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Note field
                  _FieldLabel(label: 'შენიშვნა', required: false),
                  const SizedBox(height: AppTheme.spaceS),
                  _GlassTextField(
                    controller: _noteCtrl,
                    hint: 'სურვილისამებრ',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppTheme.spaceL),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceS),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _saving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                              border: Border.all(
                                color: AppTheme.primary.withAlpha(77),
                              ),
                            ),
                            child: _saving
                                ? const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'შენახვა',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
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
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _FieldLabel({required this.label, required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
          ),
        ] else ...[
          const SizedBox(width: 4),
          const Text(
            '(სურვილისამებრ)',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ],
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? error;
  final bool autofocus;
  final int maxLines;
  final void Function(String)? onChanged;

  const _GlassTextField({
    required this.controller,
    required this.hint,
    this.error,
    this.autofocus = false,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: error != null
                  ? AppTheme.errorColor.withAlpha(128)
                  : AppTheme.glassBorder,
            ),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            maxLines: maxLines,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceM,
                vertical: 12,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: const TextStyle(fontSize: 11, color: AppTheme.errorColor),
          ),
        ],
      ],
    );
  }
}
