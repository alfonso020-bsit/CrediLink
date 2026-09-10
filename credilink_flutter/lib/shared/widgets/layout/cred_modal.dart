import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

/// Platform-aware modal: bottom sheet on mobile, centered dialog on web.
Future<T?> showCredModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool barrierDismissible = true,
  /// Max width of the centered web dialog.
  double maxWidth = 560,
  Color? backgroundColor,
}) {
  if (kIsWeb) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.9;
        return Dialog(
          backgroundColor: backgroundColor ?? CredTheme.cardBackground,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CredTheme.radiusCard),
          ),
          child: SizedBox(
            width: maxWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: builder(ctx),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}

/// Tall list/detail body: drag sheet on mobile, fixed height on web.
Widget credDraggableModalBody({
  required Widget child,
  double initialChildSize = 0.7,
  double minChildSize = 0.4,
  double maxChildSize = 0.95,
  double webHeightFraction = 0.8,
}) {
  if (kIsWeb) {
    return Builder(
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * webHeightFraction;
        return SizedBox(height: height, child: child);
      },
    );
  }
  return DraggableScrollableSheet(
    expand: false,
    initialChildSize: initialChildSize,
    minChildSize: minChildSize,
    maxChildSize: maxChildSize,
    builder: (context, _) => child,
  );
}

/// Close control for web-centered modals (hidden on mobile bottom sheets).
class CredModalCloseButton extends StatelessWidget {
  const CredModalCloseButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Close',
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.close),
    );
  }
}
