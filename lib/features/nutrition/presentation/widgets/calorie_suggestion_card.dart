import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../progress/domain/progress_format.dart';
import '../../../settings/application/profile_saver.dart';
import '../../../workout/application/session_providers.dart';
import '../../domain/adaptive_tdee.dart';

/// Haftalık değişim bu eşiğin altındaysa "sabit" sayılır.
const _stableKg = 0.05;

/// Hedef düzeltme önerisi (G3 spec §5.1): neon sol kenar, eski → yeni hedef, yöntem,
/// "Şimdi değil" / "Uygula".
class CalorieSuggestionCard extends ConsumerStatefulWidget {
  const CalorieSuggestionCard({super.key, required this.suggestion});

  final CalorieSuggestion suggestion;

  @override
  ConsumerState<CalorieSuggestionCard> createState() => _CalorieSuggestionCardState();
}

class _CalorieSuggestionCardState extends ConsumerState<CalorieSuggestionCard> {
  bool _busy = false;

  Future<void> _write(Map<String, dynamic> fields, {String? successMessage}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await saveProfileChanges(ref, fields);
    // Başarıda profil yenilenir ve kart kaybolabilir; mesaj yine gösterilir.
    if (mounted) setState(() => _busy = false);
    final message = ok ? successMessage : 'settings.save_error'.tr();
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _body() {
    final s = widget.suggestion;
    final days = s.windowDays.toString();
    final observed = s.observedWeeklyKg;
    final change = observed <= -_stableKg
        ? 'nutrition.suggestion_lost'.tr(namedArgs: {'days': days, 'kg': formatOneDecimal(observed.abs())})
        : observed >= _stableKg
            ? 'nutrition.suggestion_gained'.tr(namedArgs: {'days': days, 'kg': formatOneDecimal(observed)})
            : 'nutrition.suggestion_stable'.tr(namedArgs: {'days': days});
    final expected = s.expectedWeeklyKg;
    final goal = expected < 0
        ? 'nutrition.suggestion_goal_lose'.tr(namedArgs: {'kg': formatOneDecimal(expected.abs())})
        : expected > 0
            ? 'nutrition.suggestion_goal_gain'.tr(namedArgs: {'kg': formatOneDecimal(expected)})
            : 'nutrition.suggestion_goal_maintain'.tr();
    return '$change, $goal ${'nutrition.suggestion_question'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final newTarget = s.newTarget.round().toString();
    const heading = TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900, fontSize: 20);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // Tek kenarlı çerçeve borderRadius ile verilemez; köşeleri ClipRRect yuvarlar.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: const Key('calorie_suggestion_card'),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            border: Border(left: BorderSide(color: scheme.primary, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'nutrition.suggestion_title'.tr(),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(_body(), key: const Key('suggestion_body'), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text.rich(
                key: const Key('suggestion_targets'),
                TextSpan(children: [
                  TextSpan(text: '${s.currentTarget.round()} → ', style: heading),
                  TextSpan(text: newTarget, style: heading.copyWith(color: scheme.primary)),
                  TextSpan(
                    text: ' kcal',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                s.method == SuggestionMethod.energyBalance
                    ? 'nutrition.suggestion_method_energy'.tr()
                    : 'nutrition.suggestion_method_trend'.tr(),
                key: const Key('suggestion_method'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              // Uzun çevirilerde butonlar alt satıra geçer.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('suggestion_snooze_button'),
                      onPressed: _busy ? null : () => _write(snoozeSuggestionFields(ref.read(nowProvider)())),
                      child: Text('nutrition.suggestion_snooze'.tr()),
                    ),
                    FilledButton(
                      key: const Key('suggestion_apply_button'),
                      onPressed: _busy
                          ? null
                          : () => _write(
                                applySuggestionFields(s, ref.read(nowProvider)()),
                                successMessage: 'nutrition.suggestion_applied'.tr(namedArgs: {'kcal': newTarget}),
                              ),
                      child: Text('nutrition.suggestion_apply'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
