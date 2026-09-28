import 'package:flutter/material.dart';

import '../errors/app_exception.dart';
import '../theme/cred_theme.dart';

/// Short copy for the UI. Known app errors keep their message; everything else
/// uses [fallback] so raw exceptions never reach the screen.
String userFacingMessage(
  Object error, {
  String fallback = "Something went wrong. Try again.",
}) {
  if (error is AppException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return fallback;
}

class CredSnackBar {
  static void show(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? CredTheme.danger : null,
      ),
    );
  }

  static void error(
    BuildContext context,
    Object error, {
    String fallback = "Couldn't save. Try again.",
  }) {
    show(context, userFacingMessage(error, fallback: fallback), isError: true);
  }
}
