import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/reminder_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dataService = DataService(LocalStorageService());

  // Reminder state
  bool _reminderEnabled = false;
  int _reminderHour = 9;
  int _reminderMinute = 0;

  // Permission state
  bool _canScheduleExact = true;
  bool _canUseFullScreenIntent = true;

  // Wage
  double _dailyWage = 80.0;

  // Work schedule
  List<int> _workSchedule = [1, 2, 3, 4, 5];

  bool _isAndroid = false;
  bool _testScheduled = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _isAndroid = !kIsWeb && Platform.isAndroid;
    _init();
  }

  Future<void> _init() async {
    await _dataService.init();
    _loadSettings();
    if (_isAndroid) _checkPermissions();
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
        _initialized = true;
      });
    }
  }

  Future<void> _checkPermissions() async {
    final canExact = await ReminderService.canScheduleExactAlarms();
    final canFsi = await ReminderService.canUseFullScreenIntent();
    if (mounted) {
      setState(() {
        _canScheduleExact = canExact;
        _canUseFullScreenIntent = canFsi;
      });
    }
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    await _dataService.storage.saveReminderEnabled(value);
    if (value) {
      await ReminderService.scheduleAlarm(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
    } else {
      await ReminderService.cancelAlarm();
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
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
    await _dataService.storage.saveReminderTime(picked.hour, picked.minute);
    if (_reminderEnabled) {
      await ReminderService.scheduleAlarm(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  Future<void> _testReminder() async {
    if (!_isAndroid) {
      _showSnack('შეხსენება მხოლოდ Android-ზე მუშაობს');
      return;
    }
    await ReminderService.scheduleTestAlarm();
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
    if (confirmed == true) {
      await _dataService.clearAll();
      _showSnack('ყველა მონაცემი წაიშალა');
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
          description: 'Android 12+ — SCHEDULE_EXACT_ALARM',
          isGranted: _canScheduleExact,
          onOpenSettings: () async {
            await ReminderService.openExactAlarmSettings();
            await Future.delayed(const Duration(milliseconds: 500));
            _checkPermissions();
          },
        ),
        const Divider(color: AppTheme.glassBorder, height: 1),
        _PermissionTile(
          label: 'სრული ეკრანი',
          description: 'Android 14+ — USE_FULL_SCREEN_INTENT',
          isGranted: _canUseFullScreenIntent,
          onOpenSettings: () async {
            await ReminderService.openFullScreenIntentSettings();
            await Future.delayed(const Duration(milliseconds: 500));
            _checkPermissions();
          },
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
        const _SettingsTile(
          label: 'PayDay',
          subtitle: 'ვერსია 1.0.0',
          trailing: SizedBox.shrink(),
        ),
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
