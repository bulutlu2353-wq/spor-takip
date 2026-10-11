import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../application/challenge_providers.dart';
import '../application/social_providers.dart';
import '../domain/challenge.dart';
import '../domain/challenge_progress.dart';
import 'widgets/challenge_labels.dart';
import 'widgets/social_avatar.dart';

/// Meydan okuma kurar (S3 spec §7.3). [communityId] verilirse topluluk kipinde (davet
/// listesi yok); [friendId] önceden seçili arkadaş. Kurulunca yeni kimliği döndürür.
Future<String?> showCreateChallengeSheet(BuildContext context, {String? communityId, String? friendId}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CreateChallengeSheet(communityId: communityId, friendId: friendId),
    );

class CreateChallengeSheet extends ConsumerStatefulWidget {
  const CreateChallengeSheet({super.key, this.communityId, this.friendId});

  final String? communityId;
  final String? friendId;

  @override
  ConsumerState<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends ConsumerState<CreateChallengeSheet> {
  final _target = TextEditingController();
  final _name = TextEditingController();
  ChallengeKind _kind = ChallengeKind.race;
  ChallengeMetric _metric = ChallengeMetric.workouts;
  String? _muscle;
  int _days = 7;
  ChallengeStart _start = ChallengeStart.now;
  late final Set<String> _invitees = {?widget.friendId};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _target.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _community => widget.communityId != null;
  bool get _hasMuscle => _metric == ChallengeMetric.sets || _metric == ChallengeMetric.volume;
  double? get _targetValue => double.tryParse(_target.text.trim().replaceAll(',', '.'));
  bool get _valid => (_kind == ChallengeKind.race || (_targetValue ?? 0) > 0) && (_community || _invitees.isNotEmpty);

  String get _autoName => challengeAutoName(
        kind: _kind,
        metric: _metric,
        muscle: _hasMuscle ? _muscle : null,
        target: _targetValue,
        days: _days,
      );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final window = challengeWindow(_start, _days, ref.read(nowProvider)());
    final typed = _name.text.trim();
    final invitees = [..._invitees]..sort();
    try {
      final id = await ref.read(challengeActionsProvider).create(ChallengeDraft(
            name: typed.isEmpty ? _autoName : typed,
            kind: _kind,
            metric: _metric,
            muscle: _hasMuscle ? _muscle : null,
            target: _kind == ChallengeKind.goal ? _targetValue : null,
            startsAt: window.startsAt,
            endsAt: window.endsAt,
            communityId: widget.communityId,
            invitees: _community ? const [] : invitees,
          ));
      if (navigator.canPop()) navigator.pop(id);
    } on ChallengeException catch (e) {
      if (mounted) setState(() => _error = 'challenge.error.${e.code}'.tr());
    } catch (e, st) {
      debugPrint('create challenge failed: $e\n$st');
      if (mounted) setState(() => _error = 'social.action_error'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    final friends = _community
        ? const <FriendEntry>[]
        : ref.watch(socialOverviewProvider).value?.friends ?? const <FriendEntry>[];
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            upperCaseFor(text, lang),
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('challenge_form'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              upperCaseFor('challenge.new_title'.tr(), lang),
              style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ChallengeKind>(
              showSelectedIcon: false,
              segments: [
                for (final kind in ChallengeKind.values)
                  ButtonSegment(
                    value: kind,
                    label: Text('challenge.kind.${kind.name}'.tr(), key: Key('challenge_kind_${kind.name}')),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'challenge.kind_note.${_kind.name}'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            label('challenge.metric_label'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in ChallengeMetric.values)
                  ChoiceChip(
                    key: Key('challenge_metric_${metric.name}'),
                    label: Text(challengeMetricLabel(metric)),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() {
                      _metric = metric;
                      if (!_hasMuscle) _muscle = null;
                    }),
                  ),
              ],
            ),
            if (_hasMuscle)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String?>(
                  key: const Key('challenge_muscle'),
                  isExpanded: true,
                  initialValue: _muscle,
                  decoration: InputDecoration(labelText: 'challenge.muscle_label'.tr()),
                  items: [
                    DropdownMenuItem(value: null, child: Text('challenge.muscle_all'.tr())),
                    for (final muscle in muscleGroups)
                      DropdownMenuItem(value: muscle, child: Text(challengeMuscleLabel(muscle))),
                  ],
                  onChanged: (value) => setState(() => _muscle = value),
                ),
              ),
            if (_kind == ChallengeKind.goal)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  key: const Key('challenge_target'),
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'challenge.target_label'.tr(),
                    suffixText: 'challenge.unit.${_metric.name}'.tr(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            label('challenge.duration_label'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in challengeDurations)
                  ChoiceChip(
                    key: Key('challenge_days_$days'),
                    label: Text('challenge.days'.tr(namedArgs: {'n': '$days'})),
                    selected: _days == days,
                    onSelected: (_) => setState(() => _days = days),
                  ),
              ],
            ),
            label('challenge.start_label'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final start in ChallengeStart.values)
                  ChoiceChip(
                    key: Key('challenge_start_${start.name}'),
                    label: Text('challenge.start.${start.name}'.tr()),
                    selected: _start == start,
                    onSelected: (_) => setState(() => _start = start),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('challenge_name'),
              controller: _name,
              maxLength: 60,
              decoration: InputDecoration(labelText: 'challenge.name_label'.tr(), hintText: _autoName),
            ),
            if (!_community) ...[
              label('challenge.invite_label'
                  .tr(namedArgs: {'n': '${_invitees.length}', 'max': '$maxChallengeInvitees'})),
              for (final friend in friends)
                CheckboxListTile(
                  key: Key('challenge_invite_${friend.profile.userId}'),
                  contentPadding: EdgeInsets.zero,
                  secondary: SocialAvatar(initials: friend.profile.initials, size: 40),
                  title: Text(friend.profile.displayName),
                  value: _invitees.contains(friend.profile.userId),
                  onChanged: (checked) => setState(() {
                    if (checked != true) {
                      _invitees.remove(friend.profile.userId);
                    } else if (_invitees.length < maxChallengeInvitees) {
                      _invitees.add(friend.profile.userId);
                    }
                  }),
                ),
            ],
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error, key: const Key('challenge_form_error'), style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('challenge_form_save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _valid && !_saving ? _save : null,
              child: Text('challenge.start_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
