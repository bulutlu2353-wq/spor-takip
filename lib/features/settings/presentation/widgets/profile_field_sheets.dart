import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/domain/profile.dart';
import '../../../onboarding/presentation/widgets/big_number_field.dart';
import '../../../onboarding/presentation/widgets/choice_card.dart';
import '../../../progress/domain/progress_format.dart';
import '../../../workout/application/session_providers.dart';
import '../../application/profile_saver.dart';
import '../../domain/profile_edit.dart';
import 'settings_save_button.dart';
import 'targets_preview.dart';

/// Alt sayfayı açar (klavyeye göre yükselir).
Future<void> showProfileSheet(BuildContext context, Widget sheet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => sheet,
  );
}

/// Alt sayfaların ortak çerçevesi: başlık, düzenleyici, hedef önizlemesi ve
/// Kaydet (G2 spec §4.1). [draft] null ise girdi geçersizdir.
class SheetFrame extends ConsumerStatefulWidget {
  const SheetFrame({super.key, required this.title, required this.profile, required this.draft, required this.child});

  final String title;
  final Profile profile;
  final Profile? draft;
  final Widget child;

  @override
  ConsumerState<SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends ConsumerState<SheetFrame> {
  bool _saving = false;

  Future<void> _save(Map<String, dynamic> changes) async {
    setState(() => _saving = true);
    final ok = await saveProfileChanges(ref, changes);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.save_error'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final draft = widget.draft;
    final changes = draft == null
        ? const <String, dynamic>{}
        : profileChanges(widget.profile, draft, now: now);
    final calories = changes['daily_calorie_target'] as double?;
    final protein = changes['daily_protein_target_g'] as double?;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          widget.child,
          if (calories != null && protein != null) ...[
            const SizedBox(height: 16),
            TargetsPreview(calories: calories, proteinG: protein),
          ],
          const SizedBox(height: 16),
          SettingsSaveButton(
            key: const Key('settings_sheet_save'),
            saving: _saving,
            onPressed: changes.isEmpty ? null : () => _save(changes),
          ),
        ],
      ),
    );
  }
}

/// Boy ve doğum yılı: büyük sayı girişi.
class NumberFieldSheet extends StatefulWidget {
  const NumberFieldSheet({
    super.key,
    required this.title,
    required this.profile,
    required this.initial,
    required this.min,
    required this.max,
    required this.apply,
    this.unit,
  });

  final String title;
  final Profile profile;
  final double initial;
  final double min;
  final double max;
  final Profile Function(Profile profile, double value) apply;
  final String? unit;

  @override
  State<NumberFieldSheet> createState() => _NumberFieldSheetState();
}

class _NumberFieldSheetState extends State<NumberFieldSheet> {
  late final TextEditingController _controller = TextEditingController(text: formatOneDecimal(widget.initial));
  late double? _value = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final valid = value != null && value >= widget.min && value <= widget.max;
    return SheetFrame(
      title: widget.title,
      profile: widget.profile,
      draft: valid ? widget.apply(widget.profile, value) : null,
      child: Center(
        child: BigNumberField(
          controller: _controller,
          hintText: '',
          unit: widget.unit,
          onChanged: (v) => setState(() => _value = v),
        ),
      ),
    );
  }
}

/// Cinsiyet ve aktivite: ikonlu kartlardan biri.
class ChoiceFieldSheet<T> extends StatefulWidget {
  const ChoiceFieldSheet({
    super.key,
    required this.title,
    required this.profile,
    required this.options,
    required this.initial,
    required this.apply,
  });

  final String title;
  final Profile profile;
  final List<(T value, String label, IconData icon)> options;
  final T initial;
  final Profile Function(Profile profile, T value) apply;

  @override
  State<ChoiceFieldSheet<T>> createState() => _ChoiceFieldSheetState<T>();
}

class _ChoiceFieldSheetState<T> extends State<ChoiceFieldSheet<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.title,
      profile: widget.profile,
      draft: widget.apply(widget.profile, _value),
      child: Column(
        children: [
          for (final (value, label, icon) in widget.options) ...[
            ChoiceCard(
              key: Key('choice_option_$value'),
              label: label,
              icon: icon,
              selected: value == _value,
              onTap: () => setState(() => _value = value),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Spor: yapıyor mu, türü ve haftalık gün (onboarding ile aynı kural:
/// "hayır" → tür boş, gün 0).
class SportSheet extends StatefulWidget {
  const SportSheet({super.key, required this.profile});

  final Profile profile;

  @override
  State<SportSheet> createState() => _SportSheetState();
}

class _SportSheetState extends State<SportSheet> {
  late bool _does = widget.profile.doesExercise;
  late final TextEditingController _type = TextEditingController(text: widget.profile.sportType ?? '');
  late final TextEditingController _days =
      TextEditingController(text: widget.profile.exerciseDaysPerWeek.toString());
  late double? _dayValue = widget.profile.exerciseDaysPerWeek.toDouble();

  @override
  void dispose() {
    _type.dispose();
    _days.dispose();
    super.dispose();
  }

  Profile? get _draft {
    final profile = widget.profile;
    if (!_does) return profile.copyWith(doesExercise: false, clearSportType: true, exerciseDaysPerWeek: 0);
    final type = _type.text.trim();
    final days = _dayValue;
    if (type.isEmpty || days == null || days < 0 || days > 7 || days != days.roundToDouble()) return null;
    return profile.copyWith(doesExercise: true, sportType: type, exerciseDaysPerWeek: days.round());
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'settings.row_sport'.tr(),
      profile: widget.profile,
      draft: _draft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceCard(
            key: const Key('choice_option_true'),
            label: 'onboarding.yes'.tr(),
            icon: Icons.check,
            selected: _does,
            onTap: () => setState(() => _does = true),
          ),
          const SizedBox(height: 8),
          ChoiceCard(
            key: const Key('choice_option_false'),
            label: 'onboarding.no'.tr(),
            icon: Icons.close,
            selected: !_does,
            onTap: () => setState(() => _does = false),
          ),
          if (_does) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('settings_sport_type'),
              controller: _type,
              decoration: InputDecoration(hintText: 'onboarding.sport_type_hint'.tr()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Center(
              child: BigNumberField(
                controller: _days,
                hintText: '',
                unit: 'onboarding.days_unit'.tr(),
                onChanged: (v) => setState(() => _dayValue = v),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sağlık notları: çok satırlı metin (boş → null).
class HealthNotesSheet extends StatefulWidget {
  const HealthNotesSheet({super.key, required this.profile});

  final Profile profile;

  @override
  State<HealthNotesSheet> createState() => _HealthNotesSheetState();
}

class _HealthNotesSheetState extends State<HealthNotesSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.profile.healthNotes ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    return SheetFrame(
      title: 'settings.row_health_notes'.tr(),
      profile: widget.profile,
      draft: text.isEmpty
          ? widget.profile.copyWith(clearHealthNotes: true)
          : widget.profile.copyWith(healthNotes: text),
      child: TextField(
        key: const Key('settings_health_notes'),
        controller: _controller,
        minLines: 3,
        maxLines: 5,
        decoration: InputDecoration(hintText: 'onboarding.health_notes_hint'.tr()),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
