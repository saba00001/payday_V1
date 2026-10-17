import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class HistoryHeaderWidget extends StatelessWidget {
  const HistoryHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceM,
        AppTheme.spaceM,
        AppTheme.spaceM,
        AppTheme.spaceS,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 18,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          const Text(
            'ისტორია',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
