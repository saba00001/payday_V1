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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentPink.withAlpha(48),
                  AppTheme.secondary.withAlpha(28),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppTheme.accentPink.withAlpha(65)),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 21,
              color: AppTheme.accentPink,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ისტორია',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'სამუშაო დღეები და გადახდები',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
