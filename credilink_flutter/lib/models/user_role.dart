enum UserRole {
  admin('Admin'),
  employee('Employee'),
  customer('Customer'),
  storeOwner('StoreOwner');

  const UserRole(this.value);
  final String value;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.customer,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.storeOwner:
        return 'Store Owner';
      default:
        return value;
    }
  }

  String get routePrefix {
    switch (this) {
      case UserRole.admin:
        return '/admin';
      case UserRole.employee:
        return '/employee';
      case UserRole.customer:
        return '/customer';
      case UserRole.storeOwner:
        return '/storeowner';
    }
  }

  String get initialTabRoute => '$routePrefix/tab1';
}
