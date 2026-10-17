import 'package:flutter/material.dart';

import '../../services/update/github_release.dart';
import '../../services/update/update_installer.dart';
import '../../services/update/update_service.dart';

enum _GateState {
  checking,
  failed,
  updateRequired,
  downloading,
  permissionRequired,
  installerLaunched,
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
  late final MandatoryUpdateService _service =
      widget.updateService ?? UpdateService();
  _GateState _state = _GateState.checking;
  UpdateCheckResult? _checkResult;
  String? _error;
  String? _verifiedApkPath;
  double? _downloadProgress;
  bool _openingPermissionSettings = false;
  bool _checkingAgain = false;
  String? _dismissedTag;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addObserver(this);
      _checkForUpdate();
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
    } else {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkingAgain) return;
    _checkingAgain = true;
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
            : _GateState.checking;
        if (!result.updateRequired || _dismissedTag != result.release.tagName) {
          _error = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _GateState.failed;
        _checkResult = null;
        _error = null;
      });
    } finally {
      _checkingAgain = false;
    }
  }

  Future<void> _downloadAndInstall() async {
    final release = _checkResult?.release;
    if (release == null) {
      await _checkForUpdate();
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
    final shouldShowOffer =
        widget.enabled &&
        result != null &&
        result.updateRequired &&
        _dismissedTag != result.release.tagName;
    if (!shouldShowOffer) {
      return widget.child;
    }
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          top: 8,
          child: SafeArea(
            child: Material(
              elevation: 12,
              color: const Color(0xFF101A27),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.system_update_alt_rounded,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _state == _GateState.installerLaunched
                                ? 'დაასრულე განახლება'
                                : _state == _GateState.permissionRequired
                                ? 'საჭიროა ინსტალაციის ნებართვა'
                                : 'PayDay ${result.release.tagName} ხელმისაწვდომია',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'მოგვიანებით',
                          onPressed: () => setState(
                            () => _dismissedTag = result.release.tagName,
                          ),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    Text(
                      'დაყენებულია ${result.installedVersion} · ახალი ${result.release.tagName}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (result.release.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        result.release.notes,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                    if (_error case final String error) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(color: Color(0xFFFFB4AB)),
                      ),
                    ],
                    if (_state == _GateState.downloading) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _downloadProgress),
                    ],
                    if (_state == _GateState.permissionRequired) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Android-ის პარამეტრებში ჩართე PayDay-იდან აპების ინსტალაციის ნებართვა.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                    const SizedBox(height: 12),
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
                            ? _checkForUpdate
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}
