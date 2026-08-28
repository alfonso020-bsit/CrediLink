import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_profile.dart';
import '../models/user_profile.dart';

class EmployeeRepository {
  EmployeeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<UserProfile>> getEmployeesByStore(String storeOwnerId) async {
    final snap = await _firestore
        .collection('all_users')
        .where('role', isEqualTo: 'Employee')
        .where('store_owner_id', isEqualTo: storeOwnerId)
        .get();
    return snap.docs.map((d) => UserProfile.fromFirestore(d.id, d.data())).toList();
  }

  Future<EmployeeProfile?> getEmployeeProfile(String employeeId) async {
    final snap = await _firestore
        .collection('employee_profiles')
        .where('employee_id', isEqualTo: employeeId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return EmployeeProfile.fromFirestore(doc.id, doc.data());
  }

  Future<({UserProfile user, EmployeeProfile? profile})?> getCompleteEmployeeInfo(
    String employeeId,
  ) async {
    final userDoc = await _firestore.collection('all_users').doc(employeeId).get();
    if (!userDoc.exists || userDoc.data() == null) return null;
    final profile = await getEmployeeProfile(employeeId);
    return (
      user: UserProfile.fromFirestore(userDoc.id, userDoc.data()!),
      profile: profile,
    );
  }
}
