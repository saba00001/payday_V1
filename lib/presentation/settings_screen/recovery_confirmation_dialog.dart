import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

Future<bool?> showStartFreshConfirmation(BuildContext context) =>
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'ახალი მონაცემებით დაწყება?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'სარეზერვო ასლი ვერ მოიძებნა. არსებული მონაცემები ამჟამად '
          'აპის საცავში დარჩება, თუმცა შესაძლოა მათი აღდგენა ვერ მოხერხდეს. '
          'გაგრძელებისას აპის მონაცემების წაშლამდე შეიქმნება შიდა ნედლი ასლი. '
          'გსურს ახალი მონაცემებით დაწყება?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('გაუქმება'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('დადასტურება და დაწყება'),
          ),
        ],
      ),
    );
