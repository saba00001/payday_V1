import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/app_export.dart';
import '../../core/georgian_date_utils.dart';
import '../../services/backup/backup_document.dart';
import '../../services/backup/backup_service.dart';
import '../../services/device_authenticator.dart';
import '../../services/reminder_service.dart';
import '../../routes/app_routes.dart';
import '../settings_screen/recovery_confirmation_dialog.dart';
import 'recovery_start_screen.dart';
import './widgets/add_payment_sheet_widget.dart';
import './widgets/add_advance_sheet_widget.dart';
import './widgets/advance_management_widget.dart';
import './widgets/hero_balance_widget.dart';
import './widgets/home_background_widget.dart';
import './widgets/home_header_widget.dart';
import './widgets/monthly_summary_widget.dart';
import './widgets/object_selector_sheet_widget.dart';
import './widgets/salary_metric_strip_widget.dart';
import './widgets/today_work_section_widget.dart';

class HomeScreen extends StatefulWidget {
  static final ValueNotifier<bool> recoveryMode = ValueNotifier(false);

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // TODO: Replace with Riverpod/Bloc for production
  final _dataService = DataService(LocalStorageService());
  late final _backupService = BackupService(_dataService.storage);
  bool _initialized = false;
  bool _showStartChoice = false;
  bool _recoveryBusy = false;
  String? _loadError;
  String? _recoveryError;
  LocalBackupInventory? _backupInventory;
  bool _markingWorked = false; // Guard against rapid double-tap
  bool _reminderPromptShowing = false;

  WorkObjectModel? _todayObject;
  WorkDayModel? _todayWorkDay;
  WorkObjectModel? _yesterdayObject;
  Map<String, double> _monthlySalary = {};
  Map<String, double> _totalSalary = {};
  double _currentDailyWage = 80.0; // Current applicable wage for today
  int _summaryRefreshKey = 0; // Forces MonthlySummaryWidget rebuild on refresh

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DataService.dataRevision.addListener(_onDataRestored);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DataService.dataRevision.removeListener(_onDataRestored);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleReminderPrompt();
    }
  }

  Future<void> _onDataRestored() async {
    await _dataService.reloadFromStorage();
    _refresh();
  }

  Future<void> _init() async {
    HomeScreen.recoveryMode.value = false;
    try {
      await _dataService.storage.init();
      if (!_dataService.storage.hadExistingDataAtInitialization) {
        if (!mounted) return;
        setState(() {
          _showStartChoice = true;
          HomeScreen.recoveryMode.value = true;
        });
        unawaited(_discoverLocalBackups());
        return;
      }
      await _dataService.reloadFromStorage();
      if (!kIsWeb &&
          Platform.isAndroid &&
          _dataService.storage.loadReminderEnabled()) {
        final reminderScheduled = await _syncRestoredReminder();
        if (!reminderScheduled && kDebugMode) {
          debugPrint(
            'PayDay saved reminder could not be rescheduled on startup.',
          );
        }
      }
      HomeScreen.recoveryMode.value = false;
      _refresh();
      _handleReminderPrompt();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'PayDay dashboard initialization failed '
          '(${error.runtimeType}); local data was not cleared.',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() {
        _loadError = 'ლოკალური მონაცემების წაკითხვა ვერ მოხერხდა.';
        HomeScreen.recoveryMode.value = true;
      });
      unawaited(_discoverLocalBackups());
    }
  }

  Future<void> _handleReminderPrompt() async {
    if (!mounted ||
        !_initialized ||
        _showStartChoice ||
        _loadError != null ||
        _reminderPromptShowing) {
      return;
    }
    if (!await ReminderService.consumeReminderPrompt() || !mounted) return;

    _reminderPromptShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _showReminderPrompt();
      _reminderPromptShowing = false;
    });
  }

  Future<void> _showReminderPrompt() async {
    final activeObjects = _dataService.activeObjects;
    final existing = _dataService.getWorkDayForDate(DateTime.now());
    if (existing?.isWorked == true) {
      final savedObject = existing!.objectName.isEmpty
          ? ''
          : ' ობიექტი: ${existing.objectName}.';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('დღევანდელი სამუშაო შენახულია'),
          content: Text('სამუშაო დღე უკვე აღრიცხულია.$savedObject'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('კარგი'),
            ),
          ],
        ),
      );
      return;
    }
    final preferredObjectId =
        _todayObject?.id ??
        (existing?.objectId.isNotEmpty == true ? existing!.objectId : null) ??
        _yesterdayObject?.id;
    var selectedObjectId =
        activeObjects.any((object) => object.id == preferredObjectId)
        ? preferredObjectId
        : activeObjects.isEmpty
        ? null
        : activeObjects.first.id;
    var workedToday = true;

    final response =
        await showDialog<({bool worked, bool addObject, String? objectId})>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              surfaceTintColor: Colors.transparent,
              elevation: 28,
              shadowColor: AppTheme.primary.withValues(alpha: 0.28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.22),
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              title: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.work_history_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'დღეს იმუშავე?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<bool>(
                    groupValue: workedToday,
                    onChanged: (value) =>
                        setDialogState(() => workedToday = value ?? false),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<bool>(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          tileColor: Colors.white.withValues(alpha: 0.04),
                          selectedTileColor: AppTheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          selected: workedToday,
                          activeColor: AppTheme.primary,
                          title: Text('კი, ვიმუშავე'),
                          value: true,
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<bool>(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          tileColor: Colors.white.withValues(alpha: 0.04),
                          selectedTileColor: AppTheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          selected: !workedToday,
                          activeColor: AppTheme.primary,
                          title: Text('არა, არ მიმუშავია'),
                          value: false,
                        ),
                      ],
                    ),
                  ),
                  if (workedToday && activeObjects.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedObjectId,
                      decoration: const InputDecoration(
                        labelText: 'რომელ ობიექტზე იმუშავე?',
                      ),
                      items: activeObjects
                          .map(
                            (object) => DropdownMenuItem(
                              value: object.id,
                              child: Text(object.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedObjectId = value),
                    ),
                  ] else if (workedToday) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('ჯერ დაამატე სამუშაო ობიექტი.'),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('მოგვიანებით'),
                ),
                if (workedToday && activeObjects.isEmpty)
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, (
                      worked: false,
                      addObject: true,
                      objectId: null,
                    )),
                    child: const Text('ობიექტის დამატება'),
                  )
                else
                  FilledButton(
                    onPressed: workedToday && selectedObjectId == null
                        ? null
                        : () => Navigator.pop(dialogContext, (
                            worked: workedToday,
                            addObject: false,
                            objectId: workedToday ? selectedObjectId : null,
                          )),
                    child: const Text('დადასტურება'),
                  ),
              ],
            ),
          ),
        );
    if (!mounted || response == null) return;

    if (response.addObject) {
      _navigateToObjects();
    } else if (response.worked) {
      WorkObjectModel? selectedObject;
      for (final object in activeObjects) {
        if (object.id == response.objectId) {
          selectedObject = object;
          break;
        }
      }
      if (selectedObject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('არჩეული ობიექტი ვეღარ მოიძებნა.')),
        );
        return;
      }
      setState(() => _todayObject = selectedObject);
      await _onMarkWorked();
    } else {
      await _onMarkNotWorked();
    }
  }

  Future<void> _discoverLocalBackups() async {
    try {
      final inventory = await _backupService.discoverInternalBackups();
      if (mounted) setState(() => _backupInventory = inventory);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'PayDay startup backup discovery failed (${error.runtimeType}).',
        );
      }
      if (mounted) {
        setState(
          () => _recoveryError =
              'შიდა სარეზერვო ასლების მოძიება ვერ მოხერხდა. '
              'არსებული მონაცემები უცვლელია.',
        );
      }
    }
  }

  Future<void> _restoreExternalBackup() async {
    if (_recoveryBusy) return;
    setState(() {
      _recoveryBusy = true;
      _recoveryError = null;
    });
    try {
      final backup = await _backupService.selectBackup();
      if (!mounted || backup == null) return;
      await _restoreBackup(backup);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'PayDay external backup restore failed (${error.runtimeType}).',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        setState(() => _recoveryError = _localizedRecoveryError(error));
      }
    } finally {
      if (mounted) setState(() => _recoveryBusy = false);
    }
  }

  Future<void> _restoreLocalBackup(LocalBackupEntry entry) async {
    if (_recoveryBusy) return;
    setState(() {
      _recoveryBusy = true;
      _recoveryError = null;
    });
    try {
      await _restoreBackup(entry.document);
    } catch (error) {
      if (mounted) {
        setState(() => _recoveryError = _localizedRecoveryError(error));
      }
    } finally {
      if (mounted) setState(() => _recoveryBusy = false);
    }
  }

  Future<void> _restoreBackup(BackupDocument backup) async {
    if (_loadError != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text(
            'მონაცემების აღდგენა',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'არჩეული ასლი შეიქმნა ${_formatBackupDate(backup.createdAt)}. '
            'აღდგენამდე დაზიანებული მიმდინარე მონაცემების შიდა ასლი '
            'შეინახება. გაგრძელდეს?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('გაუქმება'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('აღდგენა'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _backupService.restore(backup);
    final reminderRestored = await _syncRestoredReminder();
    await _dataService.reloadFromStorage();
    if (!mounted) return;
    setState(() {
      _loadError = null;
      _showStartChoice = false;
      _backupInventory = null;
      _recoveryError = null;
      HomeScreen.recoveryMode.value = false;
    });
    _refresh();
    if (!reminderRestored && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'მონაცემები აღდგა, თუმცა შეხსენება ვერ ჩაირთო. '
            'შეამოწმე პარამეტრები.',
          ),
        ),
      );
    }
  }

  Future<bool> _syncRestoredReminder() async {
    final storage = _dataService.storage;
    if (!storage.loadReminderEnabled()) return ReminderService.cancelAlarm();
    if (!await ReminderService.canPostNotifications()) return false;
    return ReminderService.scheduleAlarm(
      hour: storage.loadReminderHour(),
      minute: storage.loadReminderMinute(),
    );
  }

  Future<void> _startNewData() async {
    if (_recoveryBusy) return;
    if (_loadError != null) {
      final confirmed = await showStartFreshConfirmation(context);
      if (confirmed != true || !mounted) return;
      try {
        final authenticated = await DeviceAuthenticator.authenticate(
          localizedReason:
              'მონაცემების წაშლისა და თავიდან დაწყების დასადასტურებლად',
        );
        if (!authenticated || !mounted) return;
      } on LocalAuthException {
        if (mounted) {
          setState(
            () => _recoveryError =
                'ვერიფიკაცია ვერ მოხერხდა. მონაცემები არ შეცვლილა.',
          );
        }
        return;
      }
    }
    setState(() {
      _recoveryBusy = true;
      _recoveryError = null;
    });
    try {
      if (_loadError != null) {
        await _dataService.resetUserData();
      } else {
        await _dataService.reloadFromStorage();
      }
      if (!mounted) return;
      setState(() {
        _loadError = null;
        _showStartChoice = false;
        _backupInventory = null;
        HomeScreen.recoveryMode.value = false;
      });
      _refresh();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'PayDay start-new-data action failed (${error.runtimeType}).',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        setState(() => _recoveryError = _localizedRecoveryError(error));
      }
    } finally {
      if (mounted) setState(() => _recoveryBusy = false);
    }
  }

  Future<void> _retryStorageRead() async {
    if (_recoveryBusy) return;
    setState(() {
      _recoveryBusy = true;
      _recoveryError = null;
      _backupInventory = null;
    });
    try {
      await _dataService.storage.init();
      await _dataService.reloadFromStorage();
      if (!mounted) return;
      setState(() {
        _loadError = null;
        _showStartChoice = false;
        HomeScreen.recoveryMode.value = false;
      });
      _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _recoveryError = _localizedRecoveryError(error));
      await _discoverLocalBackups();
    } finally {
      if (mounted) setState(() => _recoveryBusy = false);
    }
  }

  String _localizedRecoveryError(Object error) {
    if (error is LocalStorageException) return error.message;
    if (error is FormatException) return error.message;
    if (error is FileSystemException) {
      return 'მონაცემების უსაფრთხო ასლის შენახვა ვერ მოხერხდა. '
          'შეამოწმე მოწყობილობის თავისუფალი ადგილი და სცადე თავიდან.';
    }
    if (error is PlatformException) {
      return 'Android-ის მონაცემთა საცავი დროებით მიუწვდომელია. '
          'მონაცემები არ გასუფთავებულა; სცადე ხელახლა.';
    }
    if (kDebugMode) {
      debugPrint(
        'PayDay startup recovery action failed (${error.runtimeType}).',
      );
    }
    return 'ოპერაცია ვერ დასრულდა და მონაცემების მდგომარეობა '
        'ვერ დადასტურდა. არ წაშალო აპი; სცადე ხელახლა ან აირჩიე სხვა backup.';
  }

  String _formatBackupDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  void _refresh() {
    if (!mounted) return;
    _loadError = null;
    final now = DateTime.now();
    final todayWd = _dataService.getWorkDayForDate(now);
    WorkObjectModel? todayObj;

    if (todayWd != null && todayWd.isWorked) {
      // Today is already worked — resolve the object for display only.
      // Completed or deleted objects are still shown in the worked-state card
      // (historical display is valid), but the ვიმუშავე button must be hidden.
      if (todayWd.objectId.isNotEmpty) {
        final obj = _dataService.getObjectById(todayWd.objectId);
        // obj may be null (deleted) — that's fine, we pass null and show snapshot name
        todayObj = obj; // may be active, completed, or null (deleted)
      }
    } else {
      // No worked record yet — only allow active objects as today's selection.
      if (_todayObject != null) {
        final refreshed = _dataService.getObjectById(_todayObject!.id);
        if (refreshed != null && refreshed.status == WorkObjectStatus.active) {
          todayObj = refreshed;
        }
        // If completed or deleted, todayObj stays null → UI resets to selector
      }
    }

    setState(() {
      _initialized = true;
      _todayWorkDay = todayWd;
      _todayObject = todayObj;
      _yesterdayObject = _dataService.getYesterdayObject();
      _monthlySalary = _dataService.getSalaryForMonth(now.year, now.month);
      _totalSalary = _dataService.getTotalSalary();
      _currentDailyWage = _dataService.getDailyWageForDate(now);
      _summaryRefreshKey++; // Force MonthlySummaryWidget to reload
    });
  }

  Future<void> _reloadAndRefresh() async {
    try {
      await _dataService.reloadFromStorage();
      _refresh();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('PayDay home refresh failed (${error.runtimeType}).');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('მონაცემების განახლება ვერ მოხერხდა.')),
        );
      }
    }
  }

  Future<void> _onSelectObject(WorkObjectModel obj) async {
    final now = DateTime.now();
    final existing = _dataService.getWorkDayForDate(now);

    if (existing != null && existing.isWorked) {
      // Already worked — ask to change object only (don't re-mark worked)
      final confirm = await _showChangeObjectDialog(obj);
      if (confirm != true) return;
      // Update today's existing WorkDay objectId without creating duplicate
      final updated = existing.copyWith(
        objectId: obj.id,
        objectName: obj.name,
        updatedAt: DateTime.now(),
      );
      await _dataService.updateWorkDay(updated);
      // Also update in-memory todayObject immediately
      setState(() => _todayObject = obj);
      _refresh();
      return;
    }

    // No worked record yet — just set the selected object for today
    setState(() => _todayObject = obj);
  }

  Future<bool?> _showChangeObjectDialog(WorkObjectModel newObj) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _PayDayDialog(
        title: 'ობიექტის შეცვლა',
        message: 'გსურთ დღევანდელი ობიექტის შეცვლა?\n„${newObj.name}"-ზე?',
        confirmLabel: 'შეცვლა',
        cancelLabel: 'გაუქმება',
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  Future<void> _onMarkWorked() async {
    // Guard: prevent rapid double-tap from creating concurrent calls
    if (_markingWorked) return;

    // Determine which object to use:
    // 1. If today already has a worked record with an object, use that object.
    // 2. If _todayObject is set (active), use it.
    // 3. Otherwise show the object selector.
    final now = DateTime.now();
    final existing = _dataService.getWorkDayForDate(now);

    WorkObjectModel? objectToUse = _todayObject;

    // If reverting from not-worked state and no object is in memory,
    // try to find the most recently used active object.
    if (objectToUse == null &&
        existing != null &&
        existing.objectId.isNotEmpty) {
      final obj = _dataService.getObjectById(existing.objectId);
      if (obj != null && obj.status == WorkObjectStatus.active) {
        objectToUse = obj;
      }
    }

    if (objectToUse == null) {
      // No object selected — show selector first
      _showObjectSelector();
      return;
    }

    setState(() => _markingWorked = true);
    try {
      await _dataService.markWorked(
        date: now,
        objectId: objectToUse.id,
        objectName: objectToUse.name,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${GeorgianDateUtils.formatDate(now)} — ${objectToUse.name}',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            backgroundColor: AppTheme.surfaceVariantDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingWorked = false);
    }
  }

  Future<void> _onMarkNotWorked() async {
    await _dataService.markNotWorked(DateTime.now());
    _refresh();
  }

  void _showObjectSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ObjectSelectorSheetWidget(
        activeObjects: _dataService.activeObjects,
        onSelect: (obj) {
          Navigator.of(context).pop();
          _onSelectObject(obj);
        },
        onCreateNew: () {
          Navigator.of(context).pop();
          _showCreateObjectSheet();
        },
      ),
    );
  }

  void _showAddPayment() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddPaymentSheetWidget(
        remaining: _totalSalary['remaining'] ?? 0,
        objects: _dataService.activeObjects,
        onAdd: (amount, objectId, objectName) async {
          await _dataService.addTransaction(
            amount: amount,
            objectId: objectId,
            objectName: objectName,
          );
          _refresh();
        },
      ),
    );
  }

  void _showAddAdvance() {
    final objects = _dataService.activeObjects;
    if (objects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ჯერ დაამატე აქტიური ობიექტი')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddAdvanceSheetWidget(
        objects: objects,
        onAdd: (amount, objectId) async {
          final advance = await _dataService.addAdvance(
            amount: amount,
            objectId: objectId,
          );
          if (advance == null) return false;
          _refresh();
          return true;
        },
      ),
    );
  }

  Future<void> _deleteAdvance(String id) async {
    await _dataService.deleteAdvance(id);
    _refresh();
  }

  void _showCreateObjectSheet() {
    // Use the full CreateEditObjectSheet from objects_screen
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CreateObjectDialog(
        nameController: TextEditingController(),
        onSave: (name) async {
          if (name.trim().isEmpty) return;
          await _dataService.createObject(name: name.trim());
          if (!mounted) return;
          Navigator.of(context).pop();
          _refresh();
        },
      ),
    );
  }

  void _navigateToObjects() {
    context.push(AppRoutes.objectsScreen).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_showStartChoice || _loadError != null) {
      return RecoveryStartScreen(
        recovering: _loadError != null,
        busy: _recoveryBusy,
        error: _recoveryError,
        backupInventory: _backupInventory,
        onRestore: _restoreExternalBackup,
        onRestoreLocal: _restoreLocalBackup,
        onCreateNew: _startNewData,
        onRetry: _retryStorageRead,
      );
    }
    final now = DateTime.now();
    final dateLabel = 'დღეს, ${GeorgianDateUtils.formatDate(now)}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const HomeBackgroundWidget(),
          if (!_initialized)
            _loadError == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.errorColor,
                            size: 44,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () =>
                                context.go(AppRoutes.settingsScreen),
                            child: const Text('პარამეტრები / backup'),
                          ),
                        ],
                      ),
                    ),
                  )
          else
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: AppTheme.primary,
                backgroundColor: AppTheme.surfaceDark,
                onRefresh: _reloadAndRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: HomeHeaderWidget(dateLabel: dateLabel),
                    ),
                    SliverToBoxAdapter(
                      child: HeroBalanceWidget(
                        remaining: _totalSalary['remaining'] ?? 0,
                        earned: _totalSalary['earned'] ?? 0,
                        received: _totalSalary['received'] ?? 0,
                        advanceRepaid: _totalSalary['advanceRepaid'] ?? 0,
                        onAddPayment: _showAddPayment,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SalaryMetricStripWidget(
                        earned: _monthlySalary['earned'] ?? 0,
                        received: _monthlySalary['received'] ?? 0,
                        remaining: _monthlySalary['remaining'] ?? 0,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: TodayWorkSectionWidget(
                        todayObject: _todayObject,
                        todayWorkDay: _todayWorkDay,
                        yesterdayObject: _yesterdayObject,
                        currentDailyWage: _currentDailyWage,
                        onMarkWorked: _onMarkWorked,
                        onMarkNotWorked: _onMarkNotWorked,
                        onSelectObject: _showObjectSelector,
                        onChangeObject: _showObjectSelector,
                        onUseYesterdayObject: () {
                          if (_yesterdayObject != null) {
                            _onSelectObject(_yesterdayObject!);
                          }
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: AdvanceManagementWidget(
                        balances: _dataService.getAdvanceBalances(
                          includePaid: true,
                        ),
                        onAdd: _showAddAdvance,
                        onDelete: _deleteAdvance,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: MonthlySummaryWidget(
                        key: ValueKey(_summaryRefreshKey),
                        dataService: _dataService,
                      ),
                    ),
                    // Objects quick access
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spaceM,
                          AppTheme.spaceM,
                          AppTheme.spaceM,
                          0,
                        ),
                        child: GestureDetector(
                          onTap: _navigateToObjects,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceM,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.glassBackground,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.domain_rounded,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'ობიექტები',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppTheme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bottom padding for floating nav
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Internal dialogs ──────────────────────────────────────────────────────────

class _PayDayDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PayDayDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceVariantDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceM),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceL),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBackground,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Text(
                        cancelLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceS),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: AppTheme.primary.withAlpha(77),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _CreateObjectDialog extends StatelessWidget {
  final TextEditingController nameController;
  final void Function(String) onSave;

  const _CreateObjectDialog({
    required this.nameController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceVariantDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ახალი ობიექტი',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceM),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'ობიექტის სახელი',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.glassBackground,
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
            const SizedBox(height: AppTheme.spaceM),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceS),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSave(nameController.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: AppTheme.primary.withAlpha(77),
                        ),
                      ),
                      child: const Text(
                        'შენახვა',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
