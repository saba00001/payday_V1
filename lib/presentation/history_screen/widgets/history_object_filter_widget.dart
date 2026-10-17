import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/work_object_model.dart';

class HistoryObjectFilterWidget extends StatelessWidget {
  final List<WorkObjectModel> objects;
  final String? selectedObjectId;
  final void Function(String?) onFilter;

  const HistoryObjectFilterWidget({
    super.key,
    required this.objects,
    required this.selectedObjectId,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
        children: [
          _FilterChip(
            label: 'ყველა ობიექტი',
            selected: selectedObjectId == null,
            onTap: () => onFilter(null),
          ),
          ...objects.map(
            (obj) => _FilterChip(
              label: obj.name,
              selected: selectedObjectId == obj.id,
              onTap: () => onFilter(obj.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: AppTheme.spaceS),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withAlpha(26)
              : AppTheme.glassBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withAlpha(102)
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
