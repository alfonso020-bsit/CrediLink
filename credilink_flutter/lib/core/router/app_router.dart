import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../guards/role_route_guard.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart' show RegisterScreen, roleFromQuery;
import '../../features/auth/reset_password_screen.dart';
import '../../features/landing/landing_screen.dart';
import '../../features/shared/role_tab_configs.dart';
import '../../features/shared/role_tab_shell.dart';
import '../../repositories/repositories.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) async {
      final isLoggedIn = ref.read(authRepositoryProvider).currentUser != null;
      final path = state.matchedLocation;
      final publicRoutes = ['/home', '/login', '/register', '/forgot-password'];
      final isPublic = publicRoutes.contains(path) || path.startsWith('/reset-password');
      final isAuthRoute = path == '/login' || path == '/register';

      if (!isLoggedIn && !isPublic && !path.startsWith('/reset-password')) {
        return '/login';
      }

      if (isLoggedIn) {
        final profile = await ref.read(authRepositoryProvider).getCurrentProfile();
        if (profile == null) {
          await ref.read(authRepositoryProvider).signOut();
          ref.invalidate(currentProfileProvider);
          return path == '/login' ? null : '/login';
        }
        if (isAuthRoute || path == '/home') {
          return profile.role.initialTabRoute;
        }
        final requiredRole = RoleRouteGuard.roleForPath(path);
        if (requiredRole != null && profile.role != requiredRole) {
          return profile.role.initialTabRoute;
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, state) => RegisterScreen(
          initialRole: roleFromQuery(state.uri.queryParameters['role']),
        ),
      ),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          oobCode: state.uri.queryParameters['oobCode'] ?? '',
        ),
      ),
      ..._roleRoutes('/admin', adminTabConfig()),
      ..._roleRoutes('/storeowner', storeOwnerTabConfig()),
      ..._roleRoutes('/employee', employeeTabConfig()),
      ..._roleRoutes('/customer', customerTabConfig()),
    ],
  );
});

List<RouteBase> _roleRoutes(String prefix, RoleTabConfig config) {
  return List.generate(5, (i) {
    final tab = i + 1;
    return GoRoute(
      path: '$prefix/tab$tab',
      builder: (_, _) => RoleTabShell(config: config, currentIndex: i),
    );
  });
}

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this.ref) {
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref ref;
}
