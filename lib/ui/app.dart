import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/sign_in_screen.dart';
import 'home/home_screen.dart';
import 'leaderboard/leaderboard_screen.dart';
import 'runs/runs_screen.dart';
import 'treks/treks_screen.dart';

/// Four tabs, each keeping its own navigation state.
///
/// `StatefulShellRoute` rather than a plain `IndexedStack`: switching to Treks mid-run must not
/// rebuild the map or restart the trail query, and coming back must land where you left.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
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
              path: '/leaderboard',
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
    // Outside the shell: signing in is a full-screen errand, not a fourth tab.
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(),
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // `initialLocation: true` on a re-tap returns the branch to its root, which is what
        // tapping the current tab is expected to do.
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Runs',
          ),
          NavigationDestination(
            icon: Icon(Icons.terrain_outlined),
            selectedIcon: Icon(Icons.terrain),
            label: 'Treks',
          ),
        ],
      ),
    );
  }
}
