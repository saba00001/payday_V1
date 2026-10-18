import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './app_navigation.dart';
import '../presentation/home_screen/home_screen.dart';

class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // V3 Liquid Glass — content shows behind nav
      body: navigationShell,
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: HomeScreen.recoveryMode,
        builder: (context, recoveryMode, _) {
          if (recoveryMode && navigationShell.currentIndex == 0) {
            return const SizedBox.shrink();
          }
          return AppNavigation(navigationShell: navigationShell);
        },
      ),
    );
  }
}
