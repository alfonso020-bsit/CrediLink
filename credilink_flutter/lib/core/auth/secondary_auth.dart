import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Auth app used only to create accounts.
///
/// [FirebaseAuth.createUserWithEmailAndPassword] signs that app in as the new
/// user. Using a named app leaves the signed-in owner or employee on the default app.
class SecondaryAuth {
  SecondaryAuth._();

  static const appName = 'credilink-user-creation';

  static Future<FirebaseAuth> instance() async {
    final app = await _app();
    return FirebaseAuth.instanceFor(app: app);
  }

  /// Creates the Auth user, runs [writeProfile] while the default session stays
  /// put, then signs the creation app out. Deletes the new user if profile writes fail.
  static Future<String> createUser({
    required String email,
    required String password,
    required Future<void> Function(String uid) writeProfile,
  }) async {
    final auth = await instance();
    UserCredential? credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await writeProfile(uid);
      await auth.signOut();
      return uid;
    } catch (e) {
      await _discard(auth, credential);
      rethrow;
    }
  }

  static Future<void> _discard(FirebaseAuth auth, UserCredential? credential) async {
    try {
      await credential?.user?.delete();
    } catch (_) {}
    try {
      await auth.signOut();
    } catch (_) {}
  }

  static Future<FirebaseApp> _app() async {
    for (final existing in Firebase.apps) {
      if (existing.name == appName) return existing;
    }
    return Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
