import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';

import 'auth/profile_screen.dart';
import 'auth/sign_in_screen.dart';
import 'auth/splash_screen.dart';
import 'board/leaderboard_screen.dart';
import 'common/floating_nav_bar.dart';
import 'home/home_screen.dart';
import 'runs/runs_screen.dart';
import 'treks/treks_screen.dart';

/// Sign-in gates the whole app: a signed-out player reaches the sign-in screen and nothing
/// else, and signing out anywhere lands them back on it.
///
/// A provider rather than a global so the redirect can read the auth state, and so the router
/// re-runs its redirect whenever that state changes — including a sign-out from the profile
/// screen, or a session expiring in the background.
final routerProvider = Provider<GoRouter>((ref) {
  // Bumped on every auth change; GoRouter re-evaluates its redirect when it fires.
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // A build where Firebase never started has no way to sign in at all. It stays playable
      // on this phone alone rather than locking the player out of their own ground.
      if (!ref.read(firebaseReadyProvider)) {
        return location == '/signin' || location == '/splash' ? '/home' : null;
      }

      final auth = ref.read(authStateProvider);

      // Firebase restores a saved session asynchronously. Until it answers, hold on the
      // splash rather than flashing the sign-in screen at someone already signed in.
      if (!auth.hasValue && !auth.hasError) {
        return location == '/splash' ? null : '/splash';
      }

      final signedIn = auth.value != null;
      if (!signedIn) return location == '/signin' ? null : '/signin';
      if (location == '/signin' || location == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        path: '/signin',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SignInScreen()),
      ),

      // Four tabs, each keeping its own navigation state.
      //
      // `StatefulShellRoute` rather than a plain `IndexedStack`: switching to Treks mid-run
      // must not rebuild the map or restart the trail query, and coming back must land where
      // you left.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/board',
                builder: (context, state) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/runs',
                builder: (context, state) => const RunsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/treks',
                builder: (context, state) => const TreksScreen(),
              ),
            ],
          ),
        ],
      ),
      // Outside the shell. The map is the centre of this app, and pushing it along the tab
      // bar to make room for settings would be the wrong trade.
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The map runs underneath the floating bar. `extendBody` also adds the bar's height to
      // the body's bottom padding, which is how every tab knows how far to stay clear of it.
      extendBody: true,
      body: shell,
      bottomNavigationBar: FloatingNavBar(
        destinations: _destinations,
        currentIndex: shell.currentIndex,
        // `initialLocation: true` on a re-tap returns the branch to its root, which is what
        // tapping the current tab is expected to do.
        onSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}

const _destinations = [
  NavDestination(
    icon: Icons.map_outlined,
    selectedIcon: Icons.map_rounded,
    label: 'Map',
  ),
  NavDestination(
    icon: Icons.emoji_events_outlined,
    selectedIcon: Icons.emoji_events_rounded,
    label: 'Board',
  ),
  NavDestination(
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    label: 'Runs',
  ),
  NavDestination(
    icon: Icons.terrain_outlined,
    selectedIcon: Icons.terrain_rounded,
    label: 'Treks',
  ),
];
