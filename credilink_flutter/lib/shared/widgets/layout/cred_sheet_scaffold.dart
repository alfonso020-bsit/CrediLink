import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import 'cred_modal.dart';

class CredSheetScaffold extends StatelessWidget {
  const CredSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * (kIsWeb ? 0.88 : 0.92);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: CredTheme.spaceLg,
          right: CredTheme.spaceLg,
          top: CredTheme.spaceMd,
          bottom: media.viewInsets.bottom + CredTheme.spaceLg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!kIsWeb)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: CredTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: CredTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: CredTheme.pageTitle(context)),
                  ),
                  if (actions != null) ...actions!,
                  const CredModalCloseButton(),
                ],
              ),
              const SizedBox(height: CredTheme.spaceMd),
              if (scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    child: child,
                  ),
                )
              else
                child,
            ],
          ),
        ),
      ),
    );
  }
}
