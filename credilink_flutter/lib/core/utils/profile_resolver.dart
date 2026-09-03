import '../../models/user_profile.dart';

bool emailsCompatible(String? profileEmail, String? authEmail) {
  final auth = authEmail?.trim() ?? '';
  if (auth.isEmpty) return true;
  final profile = profileEmail?.trim() ?? '';
  if (profile.isEmpty) return true;
  return profile.toLowerCase() == auth.toLowerCase();
}

/// Picks the Firestore profile that belongs to this Firebase Auth user.
///
/// Order: `all_users/{uid}` (v2 canonical) → linked `firebase_uid` → unique email.
/// Never returns an arbitrary first email match (v1 allowed the same email on
/// more than one role).
UserProfile? resolveUserProfile({
  required String uid,
  String? authEmail,
  UserProfile? docByUid,
  List<UserProfile> linkedByFirebaseUid = const [],
  List<UserProfile> byEmail = const [],
}) {
  bool ok(UserProfile p) => emailsCompatible(p.email, authEmail);

  if (docByUid != null && ok(docByUid)) return docByUid;

  final linked = linkedByFirebaseUid.where(ok).toList();
  if (linked.length == 1) return linked.single;
  if (linked.length > 1) {
    final sameId = linked.where((p) => p.id == uid).toList();
    if (sameId.length == 1) return sameId.single;
    final exactEmail = linked
        .where((p) => (p.email ?? '').trim().toLowerCase() == (authEmail ?? '').trim().toLowerCase())
        .toList();
    if (exactEmail.length == 1) return exactEmail.single;
  }

  if (docByUid != null) return docByUid;

  final emails = byEmail.where(ok).toList();
  if (emails.isEmpty) return null;
  if (emails.length == 1) return emails.single;

  final byUid = emails.where((p) => p.id == uid).toList();
  if (byUid.length == 1) return byUid.single;
  return null;
}
