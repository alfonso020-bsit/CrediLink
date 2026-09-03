import 'package:credilink_flutter/core/utils/profile_resolver.dart';
import 'package:credilink_flutter/models/user_profile.dart';
import 'package:credilink_flutter/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile({
  required String id,
  required UserRole role,
  String? email,
  String name = 'User',
}) {
  return UserProfile(
    id: id,
    username: id,
    fullName: name,
    role: role,
    status: 'active',
    province: 'Pampanga',
    municipality: 'Angeles',
    barangay: 'Balibago',
    email: email,
  );
}

void main() {
  const uid = 'firebase-uid-1';
  const email = 'owner@store.com';

  test('prefers all_users/{uid} over a stray firebase_uid link', () {
    final canonical = _profile(id: uid, role: UserRole.storeOwner, email: email, name: 'Owner');
    final stray = _profile(id: 'legacy-customer', role: UserRole.customer, email: email, name: 'Other');

    final resolved = resolveUserProfile(
      uid: uid,
      authEmail: email,
      docByUid: canonical,
      linkedByFirebaseUid: [stray],
      byEmail: [stray, canonical],
    );

    expect(resolved?.id, uid);
    expect(resolved?.role, UserRole.storeOwner);
    expect(resolved?.fullName, 'Owner');
  });

  test('uses linked legacy profile when there is no all_users/{uid} doc', () {
    final legacy = _profile(id: 'v1-doc', role: UserRole.employee, email: email, name: 'Emp');

    final resolved = resolveUserProfile(
      uid: uid,
      authEmail: email,
      linkedByFirebaseUid: [legacy],
    );

    expect(resolved?.id, 'v1-doc');
    expect(resolved?.role, UserRole.employee);
  });

  test('does not pick a random first email when duplicates exist', () {
    final customer = _profile(id: 'cust-1', role: UserRole.customer, email: email, name: 'Cust');
    final owner = _profile(id: 'own-1', role: UserRole.storeOwner, email: email, name: 'Owner');

    final resolved = resolveUserProfile(
      uid: uid,
      authEmail: email,
      byEmail: [customer, owner],
    );

    expect(resolved, isNull);
  });

  test('unique email match is used when uid and link are missing', () {
    final only = _profile(id: 'v1-doc', role: UserRole.admin, email: email, name: 'Admin');

    final resolved = resolveUserProfile(
      uid: uid,
      authEmail: email,
      byEmail: [only],
    );

    expect(resolved?.id, 'v1-doc');
    expect(resolved?.role, UserRole.admin);
  });

  test('skips a uid doc whose email does not match the signed-in user', () {
    final wrong = _profile(id: uid, role: UserRole.customer, email: 'other@x.com', name: 'Wrong');
    final linked = _profile(id: 'v1-doc', role: UserRole.storeOwner, email: email, name: 'Right');

    final resolved = resolveUserProfile(
      uid: uid,
      authEmail: email,
      docByUid: wrong,
      linkedByFirebaseUid: [linked],
    );

    expect(resolved?.id, 'v1-doc');
    expect(resolved?.fullName, 'Right');
  });
}
