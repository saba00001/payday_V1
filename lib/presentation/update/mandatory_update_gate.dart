import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../services/update/github_release.dart';
import '../../services/update/update_installer.dart';
import '../../services/update/update_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payday_startup_mark.dart';

enum _GateState {
  checking,
  failed,
  upToDate,
  updateRequired,
  downloading,
  permissionRequired,
  installerLaunched,
  offline,
}

class MandatoryUpdateGate extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final MandatoryUpdateService? updateService;

  const MandatoryUpdateGate({
    super.key,
    required this.child,
    required this.enabled,
    this.updateService,
  });

  @override
  State<MandatoryUpdateGate> createState() => _MandatoryUpdateGateState();
}

class _MandatoryUpdateGateState extends State<MandatoryUpdateGate>
    with WidgetsBindingObserver {
  static const _automaticCheckInterval = Duration(hours: 6);

  late final MandatoryUpdateService _service =
      widget.updateService ?? UpdateService();
  _GateState _state = _GateState.checking;
  UpdateCheckResult? _checkResult;
  String? _error;
  String? _verifiedApkPath;
  double? _downloadProgress;
  bool _openingPermissionSettings = false;
  bool _checkingAgain = false;
  bool _showStartupSplash = true;
  Timer? _startupSplashTimer;
  DateTime? _lastCheckAt;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addObserver(this);
      _checkForUpdate();
    }
    _startupSplashTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() {
        _showStartupSplash = false;
        if (!widget.enabled) _state = _GateState.upToDate;
      });
    });
  }

  @override
  void dispose() {
    _startupSplashTimer?.cancel();
    if (widget.enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !widget.enabled) return;
    if (_openingPermissionSettings) {
      _openingPermissionSettings = false;
      _installVerifiedApk();
    } else if (_state == _GateState.installerLaunched ||
        _lastCheckAt == null ||
        DateTime.now().difference(_lastCheckAt!) >= _automaticCheckInterval) {
      _checkForUpdate(force: true);
    }
  }

  Future<void> _checkForUpdate({bool force = false}) async {
    if (_checkingAgain) return;
    if (!force &&
        _lastCheckAt != null &&
        DateTime.now().difference(_lastCheckAt!) < _automaticCheckInterval) {
      return;
    }
    _checkingAgain = true;
    _lastCheckAt = DateTime.now();
    setState(() {
      _state = _GateState.checking;
      _error = null;
    });
    try {
      final result = await _service.checkForUpdate();
      if (!mounted) return;
      _checkResult = result;
      setState(() {
        _state = result.updateRequired
            ? _GateState.updateRequired
            : _GateState.upToDate;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      final offline = error is UpdateException && error.isConnectivityFailure;
      if (kDebugMode) {
        debugPrint(
          'PayDay update check ${offline ? 'offline' : 'failed'} '
          '(${error.runtimeType}).',
        );
      }
      setState(() {
        _state = offline ? _GateState.offline : _GateState.failed;
        _checkResult = null;
        _error = offline ? null : _localizedError(error);
      });
    } finally {
      _checkingAgain = false;
    }
  }

  Future<void> _downloadAndInstall() async {
    final release = _checkResult?.release;
    if (release == null) {
      await _checkForUpdate(force: true);
      return;
    }
    setState(() {
      _state = _GateState.downloading;
      _error = null;
      _downloadProgress = null;
    });
    try {
      _verifiedApkPath = await _service.downloadAndVerify(
        release,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(
            () => _downloadProgress = total > 0 ? received / total : null,
          );
        },
      );
      await _installVerifiedApk();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _GateState.updateRequired;
        _error = _localizedError(error);
      });
    }
  }

  Future<void> _installVerifiedApk() async {
    final path = _verifiedApkPath;
    if (path == null) return;
    try {
      final result = await _service.installVerifiedApk(path);
      if (!mounted) return;
      setState(() {
        _state = result == InstallerResult.permissionRequired
            ? _GateState.permissionRequired
            : _GateState.installerLaunched;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _GateState.updateRequired;
        _error = _localizedError(error);
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    try {
      _openingPermissionSettings = true;
      await _service.openInstallPermissionSettings();
    } catch (error) {
      _openingPermissionSettings = false;
      if (!mounted) return;
      setState(() => _error = _localizedError(error));
    }
  }

  String _localizedError(Object error) {
    if (error is UpdateException) return error.message;
    return 'განახლება ვერ მოხერხდა. შეამოწმე ინტერნეტი და სცადე თავიდან.';
  }

  @override
  Widget build(BuildContext context) {
    if (_showStartupSplash && _state == _GateState.checking) {
      return const _UpdateStatusScreen(
        child: _UpdateProgressMark(progress: null),
      );
    }
    if (_state == _GateState.upToDate ||
        _state == _GateState.offline ||
        _state == _GateState.checking ||
        _state == _GateState.failed) {
      return widget.child;
    }
    final permissionRequired = _state == _GateState.permissionRequired;
    final installerLaunched = _state == _GateState.installerLaunched;
    final error = _error;
    return _UpdateStatusScreen(
      child: _UpdateProgressMark(
        progress: _state == _GateState.downloading ? _downloadProgress : null,
        showAction: true,
        icon: permissionRequired
            ? Icons.settings_rounded
            : installerLaunched
            ? Icons.refresh_rounded
            : Icons.system_update_alt_rounded,
        tooltip: error ??
            (permissionRequired
                ? 'ინსტალაციის ნებართვის ჩართვა'
                : installerLaunched
                ? 'განახლების ხელახლა შემოწმება'
                : 'განახლების ჩამოტვირთვა და ინსტალაცია'),
        onPressed: permissionRequired
            ? _openPermissionSettings
            : installerLaunched
            ? () => _checkForUpdate(force: true)
            : _state == _GateState.downloading
            ? null
            : _downloadAndInstall,
      ),
    );
  }
}

class _UpdateProgressMark extends StatelessWidget {
  final double? progress;
  final bool showAction;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _UpdateProgressMark({
    required this.progress,
    this.showAction = false,
    this.icon = Icons.system_update_alt_rounded,
    this.tooltip = 'განახლების შემოწმება',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const PaydayStartupMark(size: 88),
      const SizedBox(height: 24),
      SizedBox(
        width: 220,
        child: Semantics(
          label: 'განახლების ჩამოტვირთვის პროგრესი',
          child: LinearProgressIndicator(value: progress),
        ),
      ),
      if (showAction) ...[
        const SizedBox(height: 20),
        IconButton.filled(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.backgroundDark,
            minimumSize: const Size(56, 56),
          ),
        ),
      ],
    ],
  );
}

class _UpdateStatusScreen extends StatelessWidget {
  final Widget child;

  const _UpdateStatusScreen({required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundDark,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white70),
              child: IconTheme(
                data: const IconThemeData(color: AppTheme.primary),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
