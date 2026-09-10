import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../guards/role_route_guard.dart';
import '../masquerade/masquerade_provider.dart';
import '../platform/post_login_route.dart';
import '../../features/admin/admin_console_shell.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart' show RegisterScreen, roleFromQuery;
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/use_mobile_app_screen.dart';
import '../../features/landing/landing_screen.dart';
import '../../features/shared/role_tab_configs.dart';
import '../../features/shared/role_tab_shell.dart';
import '../../models/user_role.dart';
import '../../repositories/repositories.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _RouterRefreshListenable(ref),
    redirect: (context, state) async {
      final isLoggedIn = ref.read(authRepositoryProvider).currentUser != null;
      final path = state.matchedLocation;
      final publicRoutes = ['/home', '/login', '/forgot-password'];
      final isPublic = publicRoutes.contains(path) ||
          path.startsWith('/reset-password') ||
          (!kIsWeb && path == '/register');
      final isAuthRoute = path == '/login' || path == '/register';

      if (kIsWeb && path == '/register') {
        return '/login';
      }

      if (!isLoggedIn && path == '/use-app') {
        return '/login';
      }

      if (!isLoggedIn && !isPublic && !path.startsWith('/reset-password')) {
        return '/login';
      }

      if (isLoggedIn) {
        final profile = await ref.read(authRepositoryProvider).getCurrentProfile();
        if (profile == null) {
          clearMasqueradeFromRef(ref);
          await ref.read(authRepositoryProvider).signOut();
          ref.invalidate(currentProfileProvider);
          return path == '/login' ? null : '/login';
        }

        final home = postLoginRoute(profile.role);
        final masquerade = ref.read(masqueradeProvider);
        final isMasquerading = masquerade != null;
        final onStoreOwnerPath = path.startsWith('/storeowner');

        if (path == '/use-app') {
          if (roleAllowedOnPlatform(profile.role)) {
            return home;
          }
          return null;
        }

        if (kIsWeb && !roleAllowedOnPlatform(profile.role)) {
          final tryingRoleShell = RoleRouteGuard.roleForPath(path) != null;
          if (tryingRoleShell || isAuthRoute || path == '/home') {
            return '/use-app';
          }
        }

        if (isAuthRoute || path == '/home') {
          if (isMasquerading) clearMasqueradeFromRef(ref);
          return home;
        }

        // Admin may open Store Owner UI only while masquerading.
        if (profile.role == UserRole.admin && onStoreOwnerPath) {
          if (!isMasquerading) return '/admin/tab2';
          return null;
        }

        final requiredRole = RoleRouteGuard.roleForPath(path);
        if (requiredRole != null && profile.role != requiredRole) {
          final adminViewAsStoreOwner = profile.role == UserRole.admin &&
              requiredRole == UserRole.storeOwner &&
              isMasquerading;
          if (!adminViewAsStoreOwner) {
            return home;
          }
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
      GoRoute(path: '/use-app', builder: (_, _) => const UseMobileAppScreen()),
      ..._roleRoutes('/admin', adminTabConfig(), UserRole.admin),
      ..._roleRoutes('/storeowner', storeOwnerTabConfig(), UserRole.storeOwner),
      ..._roleRoutes('/employee', employeeTabConfig(), UserRole.employee),
      ..._roleRoutes('/customer', customerTabConfig(), UserRole.customer),
    ],
  );
});

List<RouteBase> _roleRoutes(String prefix, RoleTabConfig config, UserRole role) {
  return List.generate(5, (i) {
    final tab = i + 1;
    return GoRoute(
      path: '$prefix/tab$tab',
      builder: (_, _) {
        // Admin console + Admin masquerade (Store Owner on web) share desktop shell.
        if (kIsWeb && (role == UserRole.admin || role == UserRole.storeOwner)) {
          return AdminConsoleShell(config: config, currentIndex: i);
        }
        return RoleTabShell(config: config, currentIndex: i);
      },
    );
  });
}

class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(this.ref) {
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
      notifyListeners();
    });
    ref.listen<MasqueradeSession?>(masqueradeProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref ref;
}
