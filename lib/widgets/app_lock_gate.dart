import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/device_authenticator.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    this.enabled = true,
    this.authenticate,
  });

  final Widget child;
  final bool enabled;
  final Future<bool> Function()? authenticate;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_authenticate());
    } else {
      _unlocked = true;
    }
  }

  @override
  void dispose() {
    if (widget.enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled || _authenticating) return;
    if (state == AppLifecycleState.paused && _unlocked) {
      setState(() {
        _unlocked = false;
        _error = null;
      });
    } else if (state == AppLifecycleState.resumed && !_unlocked) {
      unawaited(_authenticate());
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating || !mounted) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final authenticated = await (widget.authenticate?.call() ??
          DeviceAuthenticator.authenticate(
            localizedReason:
                'PayDay-ის მონაცემების გასახსნელად დაადასტურე ვინაობა',
          ));
      if (!mounted) return;
      setState(() {
        _unlocked = authenticated;
        _error = authenticated
            ? null
            : 'გასახსნელად გამოიყენე ტელეფონის ბიომეტრია ან ეკრანის PIN-კოდი.';
      });
    } on LocalAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _unlocked = false;
        _error = error.code == LocalAuthExceptionCode.noCredentialsSet
            ? 'ჩართე ტელეფონის ბიომეტრია ან ეკრანის PIN-კოდი და სცადე ხელახლა.'
            : 'ვერიფიკაცია ვერ მოხერხდა. სცადე ხელახლა.';
      });
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest,
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 42,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PayDay დაცულია',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _authenticating
                        ? 'დაადასტურე ვინაობა გასაგრძელებლად'
                        : _error ?? 'გახსენი აპი ტელეფონის დაცვით.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _authenticating ? null : _authenticate,
                    icon: _authenticating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(_authenticating ? 'შემოწმება…' : 'გახსნა'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
