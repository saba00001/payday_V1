import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../services/update/github_release.dart';
import '../../services/update/update_installer.dart';
import '../../services/update/update_service.dart';
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
  DateTime? _lastCheckAt;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addObserver(this);
      _checkForUpdate();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 850), () {
        if (mounted) setState(() => _state = _GateState.upToDate);
      });
    }
  }

  @override
  void dispose() {
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
    final result = _checkResult;
    if (_state == _GateState.upToDate || _state == _GateState.offline) {
      return widget.child;
    }
    if (_state == _GateState.checking) {
      return const _UpdateStatusScreen(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaydayStartupMark(size: 88),
            SizedBox(height: 20),
            Text(
              'PayDay',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text('განახლების შემოწმება…'),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      );
    }
    if (_state == _GateState.failed) {
      return _UpdateStatusScreen(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 16),
            const Text(
              'განახლების შემოწმება ვერ მოხერხდა',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _checkForUpdate(force: true),
              child: const Text('ხელახლა ცდა'),
            ),
          ],
        ),
      );
    }
    if (result == null) {
      return const _UpdateStatusScreen(
        child: Text('განახლების მონაცემები მიუწვდომელია.'),
      );
    }
    return _UpdateStatusScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.system_update_alt_rounded, size: 48),
          const SizedBox(height: 16),
          Text(
            _state == _GateState.installerLaunched
                ? 'დაასრულე განახლება'
                : _state == _GateState.permissionRequired
                ? 'საჭიროა ინსტალაციის ნებართვა'
                : 'საჭიროა PayDay-ის განახლება',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'დაყენებულია ${result.installedVersion} · ახალი ${result.release.tagName}',
            textAlign: TextAlign.center,
          ),
          if (result.release.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              result.release.notes,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
          if (_error case final String error) ...[
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
          ],
          if (_state == _GateState.downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _downloadProgress),
          ],
          if (_state == _GateState.permissionRequired) ...[
            const SizedBox(height: 12),
            const Text(
              'Android-ის პარამეტრებში ჩართე PayDay-იდან აპების ინსტალაციის ნებართვა.',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          if (_state == _GateState.downloading)
            const Center(child: CircularProgressIndicator())
          else if (_state == _GateState.permissionRequired)
            FilledButton(
              onPressed: _openPermissionSettings,
              child: const Text('ნებართვის ჩართვა'),
            )
          else
            FilledButton.icon(
              onPressed: _state == _GateState.installerLaunched
                  ? () => _checkForUpdate(force: true)
                  : _downloadAndInstall,
              icon: Icon(
                _state == _GateState.installerLaunched
                    ? Icons.refresh_rounded
                    : Icons.download_rounded,
              ),
              label: Text(
                _state == _GateState.installerLaunched
                    ? 'ვერსიის შემოწმება'
                    : 'ჩამოტვირთვა და განახლება',
              ),
            ),
        ],
      ),
    );
  }
}

class _UpdateStatusScreen extends StatelessWidget {
  final Widget child;

  const _UpdateStatusScreen({required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101A27),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white70),
              child: IconTheme(
                data: const IconThemeData(color: Color(0xFF10B981)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
