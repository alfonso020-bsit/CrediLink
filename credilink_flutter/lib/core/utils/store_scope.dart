import '../../models/user_profile.dart';
import '../../models/user_role.dart';

/// Resolves the store owner ID for inventory/sales queries.
/// Employees use [UserProfile.storeOwnerId]; store owners use their own [UserProfile.id].
String resolveStoreOwnerId(UserProfile profile) {
  if (profile.role == UserRole.employee) {
    return profile.storeOwnerId ?? profile.id;
  }
  return profile.id;
}
