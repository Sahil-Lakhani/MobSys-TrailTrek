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

final routerProvider = Provider<GoRouter>((ref) {
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (!ref.read(firebaseReadyProvider)) {
        return location == '/signin' || location == '/splash' ? '/home' : null;
      }

      final auth = ref.read(authStateProvider);

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
      extendBody: true,
      body: shell,
      bottomNavigationBar: FloatingNavBar(
        destinations: _destinations,
        currentIndex: shell.currentIndex,
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
