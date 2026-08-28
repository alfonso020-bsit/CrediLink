import 'package:credilink_flutter/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserRole parses display names', () {
    expect(UserRole.storeOwner.displayName, 'Store Owner');
    expect(UserRole.fromValue('Customer'), UserRole.customer);
  });
}
