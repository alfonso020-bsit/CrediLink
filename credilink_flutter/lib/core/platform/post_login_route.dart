import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/user_role.dart';

/// Where to send a user after a successful sign-in.
///
/// On Flutter Web, only Admin may enter role shells. Other roles are directed
/// to the “use the mobile app” screen.
String postLoginRoute(UserRole role) {
  if (kIsWeb && role != UserRole.admin) {
    return '/use-app';
  }
  return role.initialTabRoute;
}

/// Whether this signed-in role may use the current platform’s role UI.
bool roleAllowedOnPlatform(UserRole role) {
  if (!kIsWeb) return true;
  return role == UserRole.admin;
}
