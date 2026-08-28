import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/errors/app_exception.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';

class StoreEmployeeData {
  const StoreEmployeeData({
    required this.username,
    required this.password,
    required this.fullName,
    required this.province,
    required this.municipality,
    required this.barangay,
    this.email,
    this.phoneNumber,
    this.region,
    this.sitioPurok,
    this.position,
  });

  final String username;
  final String password;
  final String fullName;
  final String province;
  final String municipality;
  final String barangay;
  final String? email;
  final String? phoneNumber;
  final String? region;
  final String? sitioPurok;
  final String? position;
}

class AuthRepository {
  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _auth = firebaseAuth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserProfile> signIn({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    final normalizedEmail = email.trim();
    try {
      return await _finishSignIn(
        email: normalizedEmail,
        password: password,
        selectedRole: selectedRole,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final migrated = await _tryMigrateLegacyUser(
          email: normalizedEmail,
          password: password,
          selectedRole: selectedRole,
        );
        if (migrated != null) return migrated;
      }
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        final legacy = await _findLegacyUserByEmail(normalizedEmail);
        if (legacy != null && _verifyLegacyPassword(password, legacy.data)) {
          throw const AuthException(
            'Your v1 password is correct, but Firebase Auth uses a different password. '
            'Tap Forgot Password to reset, then log in again with the same role.',
          );
        }
      }
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<UserProfile> _finishSignIn({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    final uid = user?.uid;
    if (uid == null) throw const AuthException('Login failed.');

    final profile = await _requireUserProfile(
      uid,
      email: user?.email ?? email,
    );
    if (profile.id != uid) {
      await _linkLegacyProfile(legacyDocId: profile.id, firebaseUid: uid, email: email);
    }
    return _validateProfileForRole(profile, selectedRole);
  }

  Future<UserProfile> _validateProfileForRole(UserProfile profile, UserRole selectedRole) async {
    if (!profile.isActive) {
      await _auth.signOut();
      throw const AuthException('Your account is inactive.');
    }
    if (profile.role != selectedRole) {
      await _auth.signOut();
      throw AuthException(
        'Wrong role selected. This account is a ${profile.role.displayName}. '
        'Tap ${profile.role.displayName} on the role grid and try again.',
      );
    }
    return profile;
  }

  Future<UserProfile?> _tryMigrateLegacyUser({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    final legacy = await _findLegacyUserByEmail(email);
    if (legacy == null) return null;
    if (!_verifyLegacyPassword(password, legacy.data)) return null;

    final profile = UserProfile.fromFirestore(legacy.id, legacy.data);
    await _validateProfileForRole(profile, selectedRole);

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw const AuthException(
          'This email already exists in Firebase Auth with a different password. '
          'Use Forgot Password, then log in with your correct role.',
        );
      }
      throw AuthException(_mapAuthError(e));
    }

    final uid = credential.user?.uid;
    if (uid == null) throw const AuthException('Migration failed.');
    await _linkLegacyProfile(legacyDocId: legacy.id, firebaseUid: uid, email: email);
    return profile;
  }

  Future<void> _linkLegacyProfile({
    required String legacyDocId,
    required String firebaseUid,
    required String email,
  }) async {
    await _firestore.collection('all_users').doc(legacyDocId).set({
      'firebase_uid': firebaseUid,
      'email': email,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<({String id, Map<String, dynamic> data})?> _findLegacyUserByEmail(String email) async {
    for (final candidate in {email, email.toLowerCase()}) {
      final query = await _firestore
          .collection('all_users')
          .where('email', isEqualTo: candidate)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return (id: doc.id, data: doc.data());
      }
    }
    return null;
  }

  bool _verifyLegacyPassword(String password, Map<String, dynamic> data) {
    final hash = data['password_hash'] as String?;
    if (hash == null || hash.isEmpty) return false;
    return base64.encode(utf8.encode(password)) == hash;
  }

  Future<void> register(RegisterData data) async {
    if (data.role != UserRole.customer && data.role != UserRole.storeOwner) {
      throw const AuthException('Only Customer and Store Owner can register.');
    }
    if (data.role == UserRole.storeOwner &&
        (data.storeName == null || data.storeName!.trim().isEmpty)) {
      throw const AuthException('Store name is required.');
    }
    if (await _isUsernameTaken(data.username.trim())) {
      throw const AuthException('Username is already taken.');
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: data.email.trim(),
        password: data.password,
      );
      final uid = credential.user!.uid;
      final now = DateTime.now();
      final profile = UserProfile(
        id: uid,
        username: data.username.trim(),
        fullName: data.fullName.trim(),
        role: data.role,
        status: 'active',
        email: data.email.trim(),
        phoneNumber: data.phoneNumber?.trim(),
        region: data.region?.trim(),
        province: data.province.trim(),
        municipality: data.municipality.trim(),
        barangay: data.barangay.trim(),
        sitioPurok: data.sitioPurok?.trim(),
        storeName: data.storeName?.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await _firestore.collection('all_users').doc(uid).set(profile.toFirestore());
      if (data.role == UserRole.customer) {
        await _firestore.collection('customer_profiles').doc(uid).set({
          'user_id': uid,
          'customer_id': uid,
          'full_name': profile.fullName,
          'email': profile.email,
          'province': profile.province,
          'municipality': profile.municipality,
          'barangay': profile.barangay,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      if (data.role == UserRole.storeOwner) {
        await _firestore.collection('store_profiles').doc(uid).set({
          'store_owner_id': uid,
          'store_name': profile.storeName,
          'owner_name': profile.fullName,
          'email': profile.email,
          'province': profile.province,
          'municipality': profile.municipality,
          'barangay': profile.barangay,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      await credential?.user?.delete();
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> createStoreEmployee({
    required String storeOwnerId,
    required StoreEmployeeData data,
  }) async {
    if (await _isUsernameTaken(data.username.trim())) {
      throw const AuthException('Username is already taken.');
    }

    final email = (data.email?.trim().isNotEmpty ?? false)
        ? data.email!.trim()
        : '${data.username.trim().toLowerCase()}@employees.credilink.local';

    if (data.email != null && data.email!.trim().isNotEmpty) {
      final emailTaken = await _isEmailTaken(email);
      if (emailTaken) throw const AuthException('Email already in use.');
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: data.password,
      );
      final uid = credential.user!.uid;
      final now = DateTime.now();

      final profile = UserProfile(
        id: uid,
        username: data.username.trim().toLowerCase(),
        fullName: data.fullName.trim(),
        role: UserRole.employee,
        status: 'active',
        email: email,
        phoneNumber: data.phoneNumber?.trim(),
        region: data.region?.trim(),
        province: data.province.trim(),
        municipality: data.municipality.trim(),
        barangay: data.barangay.trim(),
        sitioPurok: data.sitioPurok?.trim(),
        storeOwnerId: storeOwnerId,
        position: data.position?.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection('all_users').doc(uid).set(profile.toFirestore());
      await _firestore.collection('employee_profiles').doc(uid).set({
        'employee_id': uid,
        'store_owner_id': storeOwnerId,
        'phone_number': data.phoneNumber?.trim() ?? '',
        'position': data.position?.trim() ?? '',
        'hire_date': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      await credential?.user?.delete();
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<UserProfile?> getCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUserProfile(user.uid, email: user.email);
  }

  Future<UserProfile?> getUserProfileById(String userId) async {
    final doc = await _firestore.collection('all_users').doc(userId).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc.id, doc.data()!);
  }

  Future<void> signOut() => _auth.signOut();

  Future<List<UserProfile>> getAllUsers() async {
    final snap = await _firestore.collection('all_users').get();
    return snap.docs.map((d) => UserProfile.fromFirestore(d.id, d.data())).toList();
  }

  Future<void> updateUserStatus(String userId, String status) async {
    await _firestore.collection('all_users').doc(userId).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile({
    required String userId,
    required String fullName,
    String? email,
    String? phoneNumber,
    String? region,
    String? province,
    String? municipality,
    String? barangay,
    String? sitioPurok,
    String? position,
  }) async {
    await _firestore.collection('all_users').doc(userId).update({
      'full_name': fullName.trim(),
      if (email != null) 'email': email.trim(),
      if (phoneNumber != null) 'phone_number': phoneNumber.trim(),
      if (region != null) 'region': region.trim(),
      if (province != null) 'province': province.trim(),
      if (municipality != null) 'municipality': municipality.trim(),
      if (barangay != null) 'barangay': barangay.trim(),
      if (sitioPurok != null) 'sitio_purok': sitioPurok.trim(),
      if (position != null) 'position': position.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (position != null) {
      await _firestore.collection('employee_profiles').doc(userId).set({
        'position': position.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteEmployee(String employeeId) async {
    await _firestore.collection('all_users').doc(employeeId).delete();
    await _firestore.collection('employee_profiles').doc(employeeId).delete();
  }

  Future<void> recordEmployeeSalary({
    required String employeeId,
    required double amount,
    String? notes,
  }) async {
    await _firestore.collection('employee_profiles').doc(employeeId).collection('salary_records').add({
      'amount': amount,
      'notes': notes ?? '',
      'recorded_at': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('employee_profiles').doc(employeeId).set({
      'salary': amount,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserProfile> _requireUserProfile(String uid, {String? email}) async {
    final profile = await _fetchUserProfile(uid, email: email);
    if (profile == null) {
      await _auth.signOut();
      throw const AuthException(
        'No Firestore profile found for this account. '
        'Ensure your all_users record has an email field matching this login, '
        'or register again in the app.',
      );
    }
    return profile;
  }

  Future<UserProfile?> _fetchUserProfile(String uid, {String? email}) async {
    // Prefer explicit legacy link — avoids wrong role from a stray all_users/{uid} doc.
    final linked = await _firestore
        .collection('all_users')
        .where('firebase_uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (linked.docs.isNotEmpty) {
      final match = linked.docs.first;
      return UserProfile.fromFirestore(match.id, match.data());
    }

    final doc = await _firestore.collection('all_users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromFirestore(doc.id, doc.data()!);
    }

    final normalizedEmail = email?.trim();
    if (normalizedEmail == null || normalizedEmail.isEmpty) return null;

    final legacy = await _findLegacyUserByEmail(normalizedEmail);
    if (legacy != null) {
      return UserProfile.fromFirestore(legacy.id, legacy.data);
    }

    return null;
  }

  Future<bool> _isUsernameTaken(String username) async {
    final q = await _firestore
        .collection('all_users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<bool> _isEmailTaken(String email) async {
    for (final candidate in {email, email.toLowerCase()}) {
      final q = await _firestore
          .collection('all_users')
          .where('email', isEqualTo: candidate)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return true;
    }
    return false;
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'Email already in use.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
