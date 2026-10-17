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
    } else if (_state == _GateState.installerLaunched) {
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
      });
      if (!result.updateRequired) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _GateState.failed;
        _error = _localizedError(error);
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
    if (!widget.enabled || _checkResult != null && !_checkResult!.updateRequired) {
      return widget.child;
    }
    final result = _checkResult;
    final title = switch (_state) {
      _GateState.checking => 'განახლების შემოწმება',
      _GateState.failed => 'განახლება ვერ შემოწმდა',
      _GateState.downloading => 'განახლება იტვირთება',
      _GateState.permissionRequired => 'საჭიროა ინსტალაციის ნებართვა',
      _GateState.installerLaunched => 'დაასრულე განახლება',
      _GateState.updateRequired => 'საჭიროა PayDay-ის განახლება',
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF95),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.system_update_alt_rounded,
                      size: 58,
                      color: Color(0xFF4CAF95),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_state == _GateState.checking)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      if (result != null) ...[
                        _VersionLine(
                          label: 'დაყენებული ვერსია',
                          value: result.installedVersion,
                        ),
                        const SizedBox(height: 8),
                        _VersionLine(
                          label: 'უახლესი ვერსია',
                          value: result.release.tagName,
                        ),
                        if (result.release.notes.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'რა შეიცვალა',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(13),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                result.release.notes,
                                style: const TextStyle(
                                  height: 1.45,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFFB4AB)),
                        ),
                      ],
                      if (_state == _GateState.downloading) ...[
                        const SizedBox(height: 18),
                        LinearProgressIndicator(value: _downloadProgress),
                        const SizedBox(height: 8),
                        Text(
                          _downloadProgress == null
                              ? 'ჩამოტვირთვა მიმდინარეობს…'
                              : '${(_downloadProgress! * 100).clamp(0, 100).round()}%',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_state == _GateState.permissionRequired) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Android-ის პარამეტრებში ჩართე PayDay-იდან აპების ინსტალაციის ნებართვა. შემდეგ ავტომატურად გაგრძელდება ინსტალაცია.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                      if (_state == _GateState.installerLaunched) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'დაასრულე განახლება Android-ის ინსტალერის ეკრანზე. აპის ხელახლა გახსნისას ვერსია თავიდან შემოწმდება.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_state == _GateState.updateRequired)
                        FilledButton.icon(
                          onPressed: _downloadAndInstall,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('ჩამოტვირთვა და განახლება'),
                        )
                      else if (_state == _GateState.downloading)
                        const Center(child: CircularProgressIndicator())
                      else if (_state == _GateState.permissionRequired)
                        FilledButton(
                          onPressed: _openPermissionSettings,
                          child: const Text(
                            'უცნობი წყაროების ნებართვის ჩართვა',
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _checkForUpdate,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            _state == _GateState.installerLaunched
                                ? 'ვერსიის ხელახლა შემოწმება'
                                : 'ხელახლა ცდა',
                          ),
                        ),
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
}

class _VersionLine extends StatelessWidget {
  final String label;
  final String value;

  const _VersionLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60)),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
