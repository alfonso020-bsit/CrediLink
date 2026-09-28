import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/cred_snackbar.dart';
import 'empty_state.dart';

class CredAsyncView<T> extends StatelessWidget {
  const CredAsyncView({
    super.key,
    required this.asyncValue,
    required this.builder,
    this.loading,
    this.emptyMessage = 'No data',
    this.onRetry,
  });

  final AsyncValue<T> asyncValue;
  final Widget Function(T data) builder;
  final Widget? loading;
  final String emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => loading ?? const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        title: 'Could not load',
        message: userFacingMessage(e, fallback: 'Something went wrong. Try again.'),
        action: onRetry == null
            ? null
            : TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
      data: (data) {
        if (data is List && data.isEmpty) {
          return EmptyState(message: emptyMessage);
        }
        return builder(data);
      },
    );
  }
}
