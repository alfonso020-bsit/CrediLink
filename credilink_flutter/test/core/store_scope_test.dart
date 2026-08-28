import 'package:credilink_flutter/core/utils/store_scope.dart';
import 'package:credilink_flutter/models/user_profile.dart';
import 'package:credilink_flutter/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee uses store_owner_id', () {
    const profile = UserProfile(
      id: 'emp1',
      username: 'emp',
      fullName: 'Employee',
      role: UserRole.employee,
      status: 'active',
      province: 'P',
      municipality: 'M',
      barangay: 'B',
      storeOwnerId: 'owner1',
    );
    expect(resolveStoreOwnerId(profile), 'owner1');
  });

  test('store owner uses own id', () {
    const profile = UserProfile(
      id: 'owner1',
      username: 'owner',
      fullName: 'Owner',
      role: UserRole.storeOwner,
      status: 'active',
      province: 'P',
      municipality: 'M',
      barangay: 'B',
    );
    expect(resolveStoreOwnerId(profile), 'owner1');
  });
}
