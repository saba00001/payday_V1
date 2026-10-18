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
          'არსებული მონაცემები აპის საცავში დარჩება, თუმცა შესაძლოა მათი '
          'აღდგენა ვეღარ მოხერხდეს. გაგრძელებამდე შეიქმნება შიდა ნედლი ასლი. '
          'გსურს მონაცემების გასუფთავება და თავიდან დაწყება?',
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
