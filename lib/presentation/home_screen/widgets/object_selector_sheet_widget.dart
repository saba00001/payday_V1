import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/work_object_model.dart';

class ObjectSelectorSheetWidget extends StatefulWidget {
  final List<WorkObjectModel> activeObjects;
  final void Function(WorkObjectModel) onSelect;
  final VoidCallback onCreateNew;

  const ObjectSelectorSheetWidget({
    super.key,
    required this.activeObjects,
    required this.onSelect,
    required this.onCreateNew,
  });

  @override
  State<ObjectSelectorSheetWidget> createState() =>
      _ObjectSelectorSheetWidgetState();
}

class _ObjectSelectorSheetWidgetState extends State<ObjectSelectorSheetWidget> {
  String _search = '';

  List<WorkObjectModel> get _filtered => widget.activeObjects
      .where(
        (o) =>
            o.name.toLowerCase().contains(_search.toLowerCase()) ||
            o.address.toLowerCase().contains(_search.toLowerCase()),
      )
      .toList();

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
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppTheme.spaceS),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceM,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'ობიექტის არჩევა',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onCreateNew,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                              border: Border.all(
                                color: AppTheme.primary.withAlpha(77),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'ახალი',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceM,
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ობიექტის ძებნა...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: AppTheme.glassBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          borderSide: const BorderSide(
                            color: AppTheme.glassBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          borderSide: const BorderSide(
                            color: AppTheme.glassBorder,
                          ),
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
                  ),
                  const SizedBox(height: AppTheme.spaceS),
                  // List
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: widget.activeObjects.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceXL),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.domain_disabled_rounded,
                                  size: 36,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(height: AppTheme.spaceS),
                                const Text(
                                  'აქტიური ობიექტები არ არის',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spaceS),
                                const Text(
                                  'შექმენი ახალი ობიექტი „ახალი" ღილაკით',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceXL),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.construction_rounded,
                                  size: 36,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(height: AppTheme.spaceS),
                                const Text(
                                  'ობიექტები არ მოიძებნა',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceM,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final obj = _filtered[i];
                              return GestureDetector(
                                onTap: () => widget.onSelect(obj),
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    bottom: AppTheme.spaceS,
                                  ),
                                  padding: const EdgeInsets.all(
                                    AppTheme.spaceM,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.glassBackground,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.glassBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withAlpha(26),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusS,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.construction_rounded,
                                          size: 18,
                                          color: AppTheme.primary,
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
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            if (obj.address.isNotEmpty)
                                              Text(
                                                obj.address,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: AppTheme.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
