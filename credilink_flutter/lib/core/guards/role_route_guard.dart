import '../../models/user_role.dart';

class RoleRouteGuard {
  static UserRole? roleForPath(String path) {
    if (path.startsWith('/admin')) return UserRole.admin;
    if (path.startsWith('/storeowner')) return UserRole.storeOwner;
    if (path.startsWith('/employee')) return UserRole.employee;
    if (path.startsWith('/customer')) return UserRole.customer;
    return null;
  }

  static bool canAccess({required UserRole userRole, required String path}) {
    final requiredRole = roleForPath(path);
    if (requiredRole == null) return true;
    return userRole == requiredRole;
  }
}
