import 'package:go_router/go_router.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/calendar_screen/calendar_screen.dart';
import '../presentation/history_screen/history_screen.dart';
import '../presentation/settings_screen/settings_screen.dart';
import '../presentation/objects_screen/objects_screen.dart';
import '../widgets/app_scaffold.dart';

class AppRoutes {
  static const String initial = '/';
  static const String homeScreen = '/home-screen';
  static const String calendarScreen = '/calendar-screen';
  static const String historyScreen = '/history-screen';
  static const String settingsScreen = '/settings-screen';
  static const String objectsScreen = '/objects-screen';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.homeScreen,
  redirect: (context, state) {
    // Redirect bare "/" to the shell's home branch
    if (state.matchedLocation == AppRoutes.initial) {
      return AppRoutes.homeScreen;
    }
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.homeScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.calendarScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CalendarScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.historyScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HistoryScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settingsScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SettingsScreen()),
            ),
          ],
        ),
      ],
    ),
    // Objects screen is outside the shell (no bottom nav)
    GoRoute(
      path: AppRoutes.objectsScreen,
      builder: (context, state) => const ObjectsScreen(),
    ),
  ],
);
