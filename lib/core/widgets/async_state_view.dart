import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_view.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.state,
    required this.dataBuilder,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> state;
  final Widget Function(T data) dataBuilder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: dataBuilder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          ErrorView(message: '데이터를 불러오지 못했습니다.', onRetry: onRetry),
    );
  }
}
