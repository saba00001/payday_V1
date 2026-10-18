import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/reminder_service.dart';
import '../../services/backup/backup_document.dart';
import '../../services/backup/backup_service.dart';
import '../../services/device_authenticator.dart';
import '../../services/update/github_release.dart';
import '../../services/update/update_installer.dart';
import '../../services/update/update_service.dart';
import 'recovery_confirmation_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final MandatoryUpdateService? updateService;

  const SettingsScreen({super.key, this.updateService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _dataService = DataService(LocalStorageService());
  late final _backupService = BackupService(_dataService.storage);
  late final MandatoryUpdateService _updateService =
      widget.updateService ?? UpdateService();

  // Reminder state
  bool _reminderEnabled = false;
  int _reminderHour = 9;
  int _reminderMinute = 0;

  // Permission state
  bool _canScheduleExact = true;
  bool _canPostNotifications = true;

  // Wage
  double _dailyWage = 80.0;

  // Work schedule
  List<int> _workSchedule = [1, 2, 3, 4, 5];

  bool _isAndroid = false;
  bool _testScheduled = false;
  bool _initialized = false;
  bool _backupBusy = false;
  DateTime? _lastBackupAt;
  String? _storageError;
  String? _backupDiscoveryError;
  LocalBackupInventory? _localBackupInventory;
  String? _installedVersion;
  bool _versionLoadFailed = false;
  bool _updateBusy = false;
  double? _updateProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DataService.dataRevision.addListener(_onDataRestored);
    _isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    _loadInstalledVersion();
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
    if (state == AppLifecycleState.resumed && _isAndroid) {
      _checkPermissions();
    }
  }

  Future<void> _onDataRestored() async {
    await _dataService.reloadFromStorage();
    if (!mounted) return;
    setState(() {
      _storageError = null;
      _lastBackupAt = _dataService.storage.loadLastBackupAt();
      _reminderEnabled = _dataService.storage.loadReminderEnabled();
      _reminderHour = _dataService.storage.loadReminderHour();
      _reminderMinute = _dataService.storage.loadReminderMinute();
      _dailyWage = _dataService.storage.loadDailyWage();
      _workSchedule = _dataService.storage.loadWorkSchedule();
    });
  }

  Future<void> _init() async {
    try {
      await _dataService.init();
      _loadSettings();
      if (_isAndroid) _checkPermissions();
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          'PayDay settings could not initialize local storage. '
          'Check the preceding key-specific storage diagnostic.',
        );
      }
      if (!mounted) return;
      setState(() {
        _storageError =
            'ლოკალური მონაცემების წაკითხვა ვერ მოხერხდა. '
            'მონაცემები არ წაშლილა და აპი მათ ავტომატურად არ გაასუფთავებს. '
            'ჯერ შეამოწმე არსებული სარეზერვო ასლები.';
        _initialized = true;
      });
      _discoverLocalBackups();
    }
  }

  Future<void> _loadInstalledVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _installedVersion = packageInfo.version);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'PayDay could not read the installed package version '
          '(${error.runtimeType}).',
        );
      }
      if (mounted) setState(() => _versionLoadFailed = true);
    }
  }

  Future<void> _checkForUpdates() async {
    if (_updateBusy) return;
    setState(() {
      _updateBusy = true;
      _updateProgress = null;
    });
    try {
      final result = await _updateService.checkForUpdate();
      if (!mounted) return;
      if (!result.updateRequired) {
        _showSnack('PayDay განახლებულია');
        return;
      }
      final release = result.release;
      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                color: AppTheme.primary,
                size: 48,
              ),
              SizedBox(height: 24),
              LinearProgressIndicator(),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'დახურვა',
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.close_rounded),
            ),
            IconButton.filled(
              tooltip: 'განახლების დაწყება',
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download_rounded),
            ),
          ],
        ),
      );
      if (shouldInstall != true || !mounted) return;
      final apkPath = await _updateService.downloadAndVerify(
        release,
        onProgress: (received, total) {
          if (mounted) {
            setState(
              () => _updateProgress = total > 0 ? received / total : null,
            );
          }
        },
      );
      final installResult = await _updateService.installVerifiedApk(apkPath);
      if (!mounted) return;
      if (installResult == InstallerResult.permissionRequired) {
        await _updateService.openInstallPermissionSettings();
        _showSnack(
          'ჩართე PayDay-იდან აპების ინსტალაციის ნებართვა და დაბრუნდი აპში.',
        );
      } else {
        _showSnack('დაასრულე განახლება Android-ის ინსტალერში.');
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is UpdateException
          ? error.message
          : 'განახლების შემოწმება ან ჩამოტვირთვა ვერ მოხერხდა.';
      _showSnack(message);
    } finally {
      if (mounted) {
        setState(() {
          _updateBusy = false;
          _updateProgress = null;
        });
      }
    }
  }

  Future<void> _discoverLocalBackups() async {
    if (mounted) {
      setState(() {
        _backupDiscoveryError = null;
        _localBackupInventory = null;
      });
    }
    try {
      final inventory = await _backupService.discoverInternalBackups();
      if (mounted) setState(() => _localBackupInventory = inventory);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'PayDay local backup discovery failed (${error.runtimeType}).',
        );
      }
      if (mounted) {
        setState(
          () => _backupDiscoveryError =
              'შიდა backup-ების მოძიება ვერ მოხერხდა. '
              'არსებული მონაცემები უცვლელია; სცადე ხელახლა.',
        );
      }
    }
  }

  void _loadSettings() {
    final storage = _dataService.storage;
    if (mounted) {
      setState(() {
        _reminderEnabled = storage.loadReminderEnabled();
        _reminderHour = storage.loadReminderHour();
        _reminderMinute = storage.loadReminderMinute();
        _dailyWage = storage.loadDailyWage();
        _workSchedule = storage.loadWorkSchedule();
        _lastBackupAt = storage.loadLastBackupAt();
        _initialized = true;
      });
    }
  }

  Future<void> _createBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final createdAt = await _backupService.createExternalBackup();
      if (!mounted) return;
      if (createdAt == null) {
        _showSnack('სარეზერვო ასლის შექმნა გაუქმდა');
      } else {
        setState(() => _lastBackupAt = createdAt);
        _showSnack('სარეზერვო ასლი შენახულია არჩეულ ადგილას');
      }
    } catch (error) {
      if (mounted) _showSnack(_backupError(error));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final backup = await _backupService.selectBackup();
      if (!mounted || backup == null) return;
      await _confirmAndRestore(backup);
    } catch (error) {
      if (mounted) _showSnack(_backupError(error));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreLocalBackup(BackupDocument backup) async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      await _confirmAndRestore(backup);
    } catch (error) {
      if (mounted) _showSnack(_backupError(error));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _confirmAndRestore(BackupDocument backup) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'მონაცემების აღდგენა',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'ეს შეცვლის აპში არსებულ მონაცემებს backup-ის მონაცემებით '
          '(${_formatBackupDate(backup.createdAt)}). '
          'აღდგენამდე მიმდინარე მონაცემების შიდა ასლი შეიქმნება. გაგრძელდეს?',
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
    if (!await _authenticateSensitiveAction(
      'მონაცემების backup-იდან აღსადგენად დაადასტურე ვინაობა',
    )) {
      return;
    }
    await _backupService.restore(backup);
    final reminderRestored = await _syncReminderSettings();
    await _dataService.reloadFromStorage();
    DataService.notifyDataRestored();
    if (!mounted) return;
    setState(() {
      _storageError = null;
      _localBackupInventory = null;
      _lastBackupAt = _dataService.storage.loadLastBackupAt();
    });
    _showSnack(
      reminderRestored
          ? 'მონაცემები აღდგა'
          : 'მონაცემები აღდგა, თუმცა შეხსენება ვერ ჩაირთო. შეამოწმე ნებართვები.',
    );
  }

  Future<void> _startNewDataAfterRecoveryWarning() async {
    if (_backupBusy) return;
    final confirmed = await showStartFreshConfirmation(context);
    if (confirmed != true || !mounted) return;
    if (!await _authenticateSensitiveAction(
      'მონაცემების წაშლისა და თავიდან დაწყების დასადასტურებლად',
    )) {
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await _dataService.resetUserData();
      await _dataService.reloadFromStorage();
      DataService.notifyDataRestored();
      if (!mounted) return;
      setState(() {
        _storageError = null;
        _localBackupInventory = null;
        _lastBackupAt = null;
      });
      _loadSettings();
      _showSnack('ახალი მონაცემებით დაწყება მზად არის');
    } catch (error) {
      if (mounted) _showSnack(_backupError(error));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<bool> _syncReminderSettings() async {
    final storage = _dataService.storage;
    if (storage.loadReminderEnabled()) {
      if (!await ReminderService.canPostNotifications()) return false;
      return ReminderService.scheduleAlarm(
        hour: storage.loadReminderHour(),
        minute: storage.loadReminderMinute(),
      );
    } else {
      return ReminderService.cancelAlarm();
    }
  }

  String _backupError(Object error) {
    if (error is FormatException) return error.message.toString();
    if (error is LocalStorageException) return error.message;
    return 'სარეზერვო ასლის ოპერაცია ვერ შესრულდა. შეამოწმე თავისუფალი ადგილი და სცადე თავიდან.';
  }

  String _formatBackupDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _checkPermissions() async {
    final canExact = await ReminderService.canScheduleExactAlarms();
    final canNotify = await ReminderService.canPostNotifications();
    if (mounted) {
      setState(() {
        _canScheduleExact = canExact;
        _canPostNotifications = canNotify;
      });
    }
    if (_reminderEnabled && canNotify) {
      final scheduled = await ReminderService.scheduleAlarm(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
      if (!scheduled && kDebugMode) {
        debugPrint(
          'PayDay reminder could not be rescheduled after permission check.',
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    await ReminderService.requestNotificationPermission();
    if (!await ReminderService.canPostNotifications()) {
      await ReminderService.openNotificationSettings();
    }
    await _checkPermissions();
  }

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      var canNotify = await ReminderService.canPostNotifications();
      if (!canNotify) {
        await ReminderService.requestNotificationPermission();
        canNotify = await ReminderService.canPostNotifications();
      }
      if (!canNotify) {
        await _dataService.storage.saveReminderEnabled(false);
        await ReminderService.openNotificationSettings();
        if (mounted) {
          setState(() => _reminderEnabled = false);
          _showSnack('შეხსენებისთვის საჭიროა შეტყობინებების ნებართვა.');
        }
        return;
      }
      final scheduled = await ReminderService.scheduleAlarm(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
      await _dataService.storage.saveReminderEnabled(scheduled);
      if (mounted) {
        setState(() => _reminderEnabled = scheduled);
        if (!scheduled) _showSnack('შეხსენების დაგეგმვა ვერ მოხერხდა.');
      }
      if (scheduled &&
          !(await ReminderService.canScheduleExactAlarms()) &&
          mounted) {
        _showSnack(
          'შეხსენება ჩაირთო, თუმცა ზუსტი მაღვიძარის ნებართვის გარეშე '
          'შეიძლება დაგვიანდეს.',
        );
      }
    } else {
      await _dataService.storage.saveReminderEnabled(false);
      final cancelled = await ReminderService.cancelAlarm();
      if (mounted) {
        setState(() => _reminderEnabled = false);
        if (!cancelled) _showSnack('შეხსენების გაუქმება ვერ მოხერხდა.');
      }
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            onPrimary: Colors.black,
            surface: AppTheme.surfaceDark,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (_reminderEnabled) {
      final scheduled = await ReminderService.scheduleAlarm(
        hour: picked.hour,
        minute: picked.minute,
      );
      if (!scheduled) {
        if (mounted) {
          _showSnack('ახალი შეხსენების დროის დაგეგმვა ვერ მოხერხდა.');
        }
        return;
      }
    }
    await _dataService.storage.saveReminderTime(picked.hour, picked.minute);
    if (mounted) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
    }
  }

  Future<void> _testReminder() async {
    if (!_isAndroid) {
      _showSnack('შეხსენება მხოლოდ Android-ზე მუშაობს');
      return;
    }
    var canNotify = await ReminderService.canPostNotifications();
    if (!canNotify) {
      await ReminderService.requestNotificationPermission();
      canNotify = await ReminderService.canPostNotifications();
    }
    if (!canNotify) {
      await ReminderService.openNotificationSettings();
      if (mounted) {
        _showSnack('შეხსენების სანახავად ჩართე PayDay-ის შეტყობინებები.');
      }
      return;
    }
    final scheduled = await ReminderService.scheduleTestAlarm();
    if (!scheduled) {
      _showSnack('შეხსენების გამოცდა ვერ დაგეგმილა. შეამოწმე ნებართვები.');
      return;
    }
    setState(() => _testScheduled = true);
    _showSnack('შეხსენება 3 წამში გამოჩნდება');
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() => _testScheduled = false);
  }

  Future<void> _updateDailyWage() async {
    final controller = TextEditingController(
      text: _dailyWage.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => _WageDialog(controller: controller),
    );
    if (result != null && result > 0) {
      setState(() => _dailyWage = result);
      await _dataService.updateDailyWage(result);
    }
  }

  void _toggleWorkDay(int weekday) {
    setState(() {
      if (_workSchedule.contains(weekday)) {
        _workSchedule.remove(weekday);
      } else {
        _workSchedule.add(weekday);
        _workSchedule.sort();
      }
    });
    _dataService.storage.saveWorkSchedule(_workSchedule);
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'მონაცემების წაშლა',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'ყველა სამუშაო დღე, ობიექტი და გადახდა წაიშლება. ეს მოქმედება შეუქცევადია.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'გაუქმება',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'წაშლა',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        await _authenticateSensitiveAction(
          'ყველა მონაცემის წაშლის დასადასტურებლად',
        )) {
      try {
        await _backupService.createInternalSnapshot();
        await _dataService.clearAll();
        DataService.notifyDataRestored();
        _showSnack('მონაცემები წაიშალა. შიდა backup შეიქმნა.');
      } catch (error) {
        _showSnack(_backupError(error));
      }
    }
  }

  Future<bool> _authenticateSensitiveAction(String localizedReason) async {
    try {
      return await DeviceAuthenticator.authenticate(
        localizedReason: localizedReason,
      );
    } on LocalAuthException catch (error) {
      if (mounted) {
        _showSnack(
          error.code == LocalAuthExceptionCode.noCredentialsSet
              ? 'ტელეფონზე ჩართე ბიომეტრია ან ეკრანის PIN-კოდი.'
              : 'ვერიფიკაცია ვერ მოხერხდა. მონაცემები არ შეცვლილა.',
        );
      }
      return false;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatTime(int h, int m) {
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF050A18),
                    Color(0xFF0A1628),
                    Color(0xFF050A18),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildReminderSection(),
                      const SizedBox(height: 16),
                      _buildWageSection(),
                      const SizedBox(height: 16),
                      _buildScheduleSection(),
                      const SizedBox(height: 16),
                      if (_isAndroid) ...[
                        _buildNotificationsSection(),
                        const SizedBox(height: 16),
                      ],
                      _buildDataSection(),
                      const SizedBox(height: 16),
                      _buildAboutSection(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withAlpha(51)),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'პარამეტრები',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSection() {
    return _Section(
      title: 'შეხსენება',
      icon: Icons.alarm_rounded,
      children: [
        _SettingsTile(
          label: 'ყოველდღიური შეხსენება',
          subtitle: _reminderEnabled
              ? 'ჩართულია — ${_formatTime(_reminderHour, _reminderMinute)}'
              : 'გამორთულია',
          trailing: Switch(
            value: _reminderEnabled,
            onChanged: _toggleReminder,
            activeThumbColor: AppTheme.primary,
          ),
        ),
        if (_reminderEnabled) ...[
          const Divider(color: AppTheme.glassBorder, height: 1),
          _SettingsTile(
            label: 'შეხსენების დრო',
            subtitle: _formatTime(_reminderHour, _reminderMinute),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
            ),
            onTap: _pickReminderTime,
          ),
        ],
        const Divider(color: AppTheme.glassBorder, height: 1),
        _SettingsTile(
          label: 'შეამოწმე შეხსენება',
          subtitle: _testScheduled ? '3 წამში გამოჩნდება...' : 'ახლავე გამოცდა',
          trailing: _testScheduled
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              : const Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppTheme.primary,
                ),
          onTap: _testScheduled ? null : _testReminder,
        ),
      ],
    );
  }

  Widget _buildWageSection() {
    return _Section(
      title: 'ხელფასი',
      icon: Icons.payments_outlined,
      children: [
        _SettingsTile(
          label: 'დღიური ანაზღაურება',
          subtitle: '${_dailyWage.toStringAsFixed(0)} ₾',
          trailing: const Icon(
            Icons.edit_outlined,
            color: AppTheme.textMuted,
            size: 18,
          ),
          onTap: _updateDailyWage,
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    const days = [
      (1, 'ორშაბათი'),
      (2, 'სამშაბათი'),
      (3, 'ოთხშაბათი'),
      (4, 'ხუთშაბათი'),
      (5, 'პარასკევი'),
      (6, 'შაბათი'),
      (7, 'კვირა'),
    ];
    return _Section(
      title: 'სამუშაო გრაფიკი',
      icon: Icons.calendar_view_week_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((d) {
              final isActive = _workSchedule.contains(d.$1);
              return GestureDetector(
                onTap: () => _toggleWorkDay(d.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary.withAlpha(26)
                        : AppTheme.glassBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? AppTheme.primary.withAlpha(128)
                          : AppTheme.glassBorder,
                    ),
                  ),
                  child: Text(
                    d.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return _Section(
      title: 'შეტყობინებები',
      icon: Icons.notifications_outlined,
      children: [
        _PermissionTile(
          label: 'ზუსტი მაღვიძარა',
          description: 'Android 12+ — ზუსტი დროისთვის რეკომენდებულია',
          isGranted: _canScheduleExact,
          onOpenSettings: () async {
            await ReminderService.openExactAlarmSettings();
            await Future.delayed(const Duration(milliseconds: 500));
            _checkPermissions();
          },
        ),
        const Divider(color: AppTheme.glassBorder, height: 1),
        _PermissionTile(
          label: 'შეტყობინებების ნებართვა',
          description: 'Android 13+ — POST_NOTIFICATIONS',
          isGranted: _canPostNotifications,
          onOpenSettings: _requestNotificationPermission,
        ),
        const Divider(color: AppTheme.glassBorder, height: 1),
        _SettingsTile(
          label: 'შეტყობინების პარამეტრები',
          subtitle: 'Android-ის შეტყობინებები',
          trailing: const Icon(
            Icons.open_in_new_rounded,
            color: AppTheme.textMuted,
            size: 16,
          ),
          onTap: () async {
            await ReminderService.openNotificationSettings();
          },
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return _Section(
      title: 'მონაცემები',
      icon: Icons.storage_outlined,
      children: [
        if (_isAndroid) ...[
          if (_storageError case final String storageError) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                storageError,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ),
            const Divider(color: AppTheme.glassBorder, height: 1),
            if (_backupDiscoveryError case final String error) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
              _SettingsTile(
                label: 'Backup-ების ხელახლა მოძიება',
                subtitle: 'ახალი მონაცემებით დაწყება გამორთულია შემოწმებამდე',
                trailing: const Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.primary,
                ),
                onTap: _backupBusy ? null : _discoverLocalBackups,
              ),
            ] else if (_localBackupInventory == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_localBackupInventory!.backups.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _localBackupInventory!.invalidFiles == 0
                      ? 'გამოსაყენებელი შიდა backup ვერ მოიძებნა. '
                            'შეგიძლია გარე backup ფაილის არჩევა ქვემოთ.'
                      : 'შიდა backup-ების '
                            '${_localBackupInventory!.invalidFiles} ფაილი '
                            'დაზიანებულია ან ამ ვერსიასთან შეუთავსებელია. '
                            'არსებული მონაცემები უცვლელი რჩება.',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              _SettingsTile(
                label: 'ახალი მონაცემებით დაწყება…',
                subtitle: 'მხოლოდ დადასტურების შემდეგ შეიქმნება ახალი საცავი',
                trailing: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.errorColor,
                ),
                labelColor: AppTheme.errorColor,
                onTap: _backupBusy ? null : _startNewDataAfterRecoveryWarning,
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'შიდა სარეზერვო ასლები მოიძებნა. აირჩიე ასლი აღსადგენად; '
                  'გაუქმების შემთხვევაში არსებული მონაცემები უცვლელი დარჩება.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              for (final entry in _localBackupInventory!.backups)
                _SettingsTile(
                  label: 'შიდა backup',
                  subtitle: _formatBackupDate(entry.document.createdAt),
                  trailing: const Icon(
                    Icons.restore_rounded,
                    color: AppTheme.primary,
                  ),
                  onTap: _backupBusy
                      ? null
                      : () => _restoreLocalBackup(entry.document),
                ),
            ],
            const Divider(color: AppTheme.glassBorder, height: 1),
          ],
          _SettingsTile(
            label: 'სარეზერვო ასლის შექმნა',
            subtitle: _backupBusy
                ? 'მიმდინარეობს…'
                : _lastBackupAt == null
                ? 'ბოლო ასლი: არ არის'
                : 'ბოლო ასლი: ${_formatBackupDate(_lastBackupAt!)}',
            trailing: _backupBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.save_alt_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
            onTap: _backupBusy ? null : _createBackup,
          ),
          const Divider(color: AppTheme.glassBorder, height: 1),
          _SettingsTile(
            label: 'სარეზერვო ასლიდან აღდგენა',
            subtitle: 'აირჩიე ადრე შენახული PayDay backup ფაილი',
            trailing: const Icon(
              Icons.restore_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
            onTap: _backupBusy ? null : _restoreBackup,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'აპის წაშლისას პირადი მონაცემები იშლება. ხელახლა დაყენების შემდეგ მონაცემების დასაბრუნებლად შეინახე backup აპის საქაღალდის გარეთ.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          const Divider(color: AppTheme.glassBorder, height: 1),
        ],
        _SettingsTile(
          label: 'ობიექტები',
          subtitle: 'სამუშაო ობიექტების მართვა',
          trailing: const Icon(
            Icons.domain_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
          onTap: () => context
              .push(AppRoutes.objectsScreen)
              .then((_) => _loadSettings()),
        ),
        const Divider(color: AppTheme.glassBorder, height: 1),
        _SettingsTile(
          label: 'ყველა მონაცემის წაშლა',
          subtitle: 'სამუშაო დღეები, ობიექტები, გადახდები',
          trailing: const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.errorColor,
            size: 20,
          ),
          onTap: _clearAllData,
          labelColor: AppTheme.errorColor,
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _Section(
      title: 'აპის შესახებ',
      icon: Icons.info_outline_rounded,
      children: [
        _SettingsTile(
          label: 'PayDay',
          subtitle: _installedVersion != null
              ? 'ვერსია $_installedVersion'
              : _versionLoadFailed
              ? 'დაინსტალირებული ვერსიის წაკითხვა ვერ მოხერხდა'
              : 'ვერსიის ჩატვირთვა…',
          trailing: const SizedBox.shrink(),
        ),
        if (_isAndroid) ...[
          const Divider(color: AppTheme.glassBorder, height: 1),
          _SettingsTile(
            label: 'განახლების შემოწმება',
            subtitle: 'შეამოწმე ახალი ვერსია',
            trailing: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _updateBusy
                  ? SizedBox(
                      key: ValueKey('update-progress'),
                      width: 48,
                      child: LinearProgressIndicator(value: _updateProgress),
                    )
                  : const Icon(
                      key: ValueKey('update-icon'),
                      Icons.system_update_alt_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
            ),
            onTap: _updateBusy ? null : _checkForUpdates,
          ),
        ],
        const Divider(color: AppTheme.glassBorder, height: 1),
        const _SettingsTile(
          label: 'ყველა მონაცემი ლოკალურია',
          subtitle: 'ინტერნეტი, სერვერი ან ანგარიში არ გამოიყენება',
          trailing: Icon(
            Icons.lock_outline_rounded,
            color: AppTheme.success,
            size: 18,
          ),
        ),
      ],
    );
  }
}

// ── Reusable Section ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.primary.withAlpha(180)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.glassBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? labelColor;

  const _SettingsTile({
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ── Permission Tile ───────────────────────────────────────────────────────────

class _PermissionTile extends StatelessWidget {
  final String label;
  final String description;
  final bool isGranted;
  final VoidCallback onOpenSettings;

  const _PermissionTile({
    required this.label,
    required this.description,
    required this.isGranted,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withAlpha(77)),
              ),
              child: const Text(
                'ჩართულია',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onOpenSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withAlpha(77)),
                ),
                child: const Text(
                  'ნებართვა',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Wage Dialog ───────────────────────────────────────────────────────────────

class _WageDialog extends StatelessWidget {
  final TextEditingController controller;

  const _WageDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'დღიური ანაზღაურება',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          suffixText: '₾',
          suffixStyle: const TextStyle(color: AppTheme.primary, fontSize: 18),
          filled: true,
          fillColor: AppTheme.glassBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.glassBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'გაუქმება',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final val = double.tryParse(controller.text.trim());
            if (val != null && val > 0) Navigator.pop(context, val);
          },
          child: const Text(
            'შენახვა',
            style: TextStyle(color: AppTheme.primary),
          ),
        ),
      ],
    );
  }
}
