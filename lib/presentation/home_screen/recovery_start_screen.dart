import 'package:flutter/material.dart';

import '../../services/backup/backup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payday_startup_mark.dart';

class RecoveryStartScreen extends StatelessWidget {
  final bool recovering;
  final bool busy;
  final String? error;
  final LocalBackupInventory? backupInventory;
  final VoidCallback onRestore;
  final void Function(LocalBackupEntry backup) onRestoreLocal;
  final VoidCallback onCreateNew;
  final VoidCallback onRetry;

  const RecoveryStartScreen({
    super.key,
    required this.recovering,
    required this.busy,
    required this.error,
    required this.backupInventory,
    required this.onRestore,
    required this.onRestoreLocal,
    required this.onCreateNew,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final inventory = backupInventory;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080C14), Color(0xFF111C2B), Color(0xFF080C14)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PaydayStartupMark(size: 82),
                    const SizedBox(height: 20),
                    const Text(
                      'PayDay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recovering
                          ? 'ლოკალური მონაცემების წაკითხვა ვერ მოხერხდა. '
                                'მონაცემები არ წაშლილა. სცადე აღდგენა ან '
                                'ხელით აირჩიე ახალი მონაცემებით დაწყება.'
                          : 'მოგესალმები! შეგიძლია აღადგინო სარეზერვო ასლი '
                                'ან შექმნა ახალი მონაცემები.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : onRestore,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('მონაცემების აღდგენა'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onCreateNew,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('ახალი მონაცემების შექმნა'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          minimumSize: const Size.fromHeight(54),
                          side: BorderSide(
                            color: AppTheme.primary.withAlpha(150),
                          ),
                        ),
                      ),
                    ),
                    if (recovering && inventory == null) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: busy ? null : onRetry,
                        child: const Text('ხელახლა ცდა'),
                      ),
                    ],
                    if (recovering &&
                        inventory != null &&
                        inventory.backups.isEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'შიდა სარეზერვო ასლი ვერ მოიძებნა. შეგიძლია '
                        'შეარჩიო გარე backup ან ახალი მონაცემები შექმნა.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                    if (inventory?.backups.isNotEmpty ?? false) ...[
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'მოძიებული შიდა ასლები',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final backup in inventory!.backups)
                        Card(
                          color: AppTheme.surfaceDark,
                          child: ListTile(
                            leading: const Icon(
                              Icons.history_rounded,
                              color: AppTheme.primary,
                            ),
                            title: Text(
                              _formatDate(backup.document.createdAt),
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'შიდა სარეზერვო ასლი',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.primary,
                            ),
                            onTap: busy ? null : () => onRestoreLocal(backup),
                          ),
                        ),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
