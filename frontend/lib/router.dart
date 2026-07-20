import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/connectivity_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding/github_connect_screen.dart';
import 'screens/onboarding/linkedin_simulated_screen.dart';
import 'screens/onboarding/role_select_screen.dart';
import 'screens/projects/intent_editor_screen.dart';
import 'screens/projects/project_detail_screen.dart';
import 'screens/projects/project_form_screen.dart';
import 'state/auth_provider.dart';
import 'theme/palette.dart';

/// Builds the app router, gated by the Trust Gateway onboarding state held in
/// [auth].
///
/// Routes:
///   `/`                    → splash; redirects to the right place once booted
///   `/dev`                 → ConnectivityScreen (dev tool: backend checks)
///   `/login`               → LoginScreen (dev tool: dev-login)
///   `/onboarding/github`   → STEP 1 · connect GitHub
///   `/onboarding/linkedin` → STEP 2 · simulated LinkedIn consent
///   `/onboarding/role`     → STEP 3 · choose primary role
///   `/home`                → shared role home (bottom nav: Home/Plaza/Profile)
///   `/plaza`               → discovery feed (Home shell, Plaza tab)
///   `/projects/new`        → create a project
///   `/projects/:id`        → project detail
///   `/projects/:id/edit`   → edit a project
///   `/intent`              → collaboration-intent editor
///
/// Default entry (UX fix): first launch shows the PRODUCT, not the debug
/// screen. An onboarding-complete user landing on `/` is sent to `/home`; a new
/// user to `/onboarding/github`. The old system-check screen now lives at `/dev`.
GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      // Wait until we've tried to restore a session before gating anything.
      if (!auth.bootstrapped) return null;

      final loc = state.matchedLocation;

      // Dev tools stay reachable so debugging is easy during the demo.
      const devRoutes = {'/dev', '/login'};
      if (devRoutes.contains(loc)) return null;

      final user = auth.currentUser;
      final onboardingComplete = user?.onboardingComplete ?? false;
      final linkedinConnected = user?.linkedinConnected ?? false;

      // Fully onboarded: send the splash to Home and keep them out of the
      // onboarding flow; everything else (home/plaza/projects/intent) is fine.
      if (onboardingComplete) {
        if (loc == '/' || loc.startsWith('/onboarding')) return '/home';
        return null;
      }

      // Step 1 — no user yet: must connect GitHub.
      if (user == null) {
        return loc == '/onboarding/github' ? null : '/onboarding/github';
      }

      // Step 2 — GitHub connected, LinkedIn not bound.
      if (!linkedinConnected) {
        if (loc == '/onboarding/github' || loc == '/onboarding/linkedin') {
          return null;
        }
        return '/onboarding/linkedin';
      }

      // Step 3 — LinkedIn bound, role not chosen yet.
      return loc == '/onboarding/role' ? null : '/onboarding/role';
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _Splash(),
      ),
      GoRoute(
        path: '/dev',
        builder: (context, state) => const ConnectivityScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding/github',
        builder: (context, state) => const GithubConnectScreen(),
      ),
      GoRoute(
        path: '/onboarding/linkedin',
        builder: (context, state) => const LinkedInSimulatedScreen(),
      ),
      GoRoute(
        path: '/onboarding/role',
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/plaza',
        builder: (context, state) => const HomeShell(initialIndex: 1),
      ),
      GoRoute(
        path: '/intent',
        builder: (context, state) => const IntentEditorScreen(),
      ),
      GoRoute(
        path: '/projects/new',
        builder: (context, state) => const ProjectFormScreen(),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/projects/:id/edit',
        builder: (context, state) =>
            ProjectFormScreen(projectId: state.pathParameters['id']!),
      ),
    ],
  );
}

/// The neutral splash shown at `/` while the session is being restored. The
/// top-level [GoRouter.redirect] moves the user on to Home or onboarding as
/// soon as [AuthProvider.bootstrap] finishes.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Palette.cream50,
      body: Center(child: CircularProgressIndicator(color: Palette.ink)),
    );
  }
}
