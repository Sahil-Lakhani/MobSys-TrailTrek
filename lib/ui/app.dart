import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/profile_screen.dart';
import 'auth/sign_in_screen.dart';
import 'board/leaderboard_screen.dart';
import 'common/floating_nav_bar.dart';
import 'home/home_screen.dart';
import 'runs/runs_screen.dart';
import 'treks/treks_screen.dart';

/// Five tabs, each keeping its own navigation state.
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
        // Its own tab: who you are, your picture and name, and signing in or out.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    // Outside the shell: signing in is a full-screen errand, not a tab.
    GoRoute(path: '/signin', builder: (context, state) => const SignInScreen()),
  ],
);

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
  NavDestination(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];
