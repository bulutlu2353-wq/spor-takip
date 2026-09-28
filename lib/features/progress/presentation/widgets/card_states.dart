import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class CardLoading extends StatelessWidget {
  const CardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Kartın kendi hatası; ana sayfanın geri kalanını bozmaz (spec §7).
class CardError extends StatelessWidget {
  const CardError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text('progress.load_error'.tr()),
      trailing: TextButton(
        key: const Key('card_retry'),
        onPressed: onRetry,
        child: Text('progress.retry'.tr()),
      ),
    );
  }
}

class ProgressCardHeader extends StatelessWidget {
  const ProgressCardHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        ?trailing,
      ],
    );
  }
}
