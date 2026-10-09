import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text_case.dart';
import '../../../shared/widgets/accent_chip.dart';
import '../application/muscle_heat_providers.dart';
import '../application/muscle_map_providers.dart';
import '../application/session_providers.dart';
import '../application/workout_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import '../domain/exercise_taxonomy.dart';
import '../domain/muscle_heat.dart';
import '../domain/muscle_map.dart';
import 'widgets/exercise_detail_sheet.dart';
import 'widgets/exercise_icon_badge.dart';
import 'widgets/muscle_map.dart';

/// Kas haritası: kasa dokun → o kası çalıştıran hareketler (yalnız göz atma).
/// ISI modunda son 7/30 günün setleri, [programId] verilirse programın planlı setleri tonlanır (K3 spec §5.2).
class MuscleMapScreen extends ConsumerStatefulWidget {
  const MuscleMapScreen({super.key, this.programId});

  final String? programId;

  @override
  ConsumerState<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends ConsumerState<MuscleMapScreen> {
  BodyView _view = BodyView.front;
  String? _muscle;
  bool _includeSecondary = false;
  bool _heatMode = false;
  int _days = 7;

  bool get _showsHeat => widget.programId != null || _heatMode;

  /// Haritada gösterilecek yük; ısı kapalıyken, yüklenirken ya da hatada null.
  MuscleLoad? _load() {
    final programId = widget.programId;
    if (programId != null) return ref.watch(programHeatProvider(programId)).value?.load;
    if (_heatMode) return ref.watch(historyHeatProvider(_days)).value?.load;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final muscle = _muscle;
    final programId = widget.programId;
    final figure = ref.watch(mapFigureProvider);
    final lang = context.locale.languageCode;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final load = _load();
    final heat = load == null ? const <String, HeatTier>{} : heatTiers(load, days: programId == null ? _days : null);
    final programName = programId == null ? null : ref.watch(programDetailProvider(programId)).value?.name;
    final noWorkouts = programId == null && _heatMode && load != null && load.isEmpty;
    return Scaffold(
      key: const Key('muscle_map_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('workout.muscle_map.title'.tr(), lang),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (programName != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(programName, key: const Key('muscle_map_program_name'), style: muted),
              ),
            ),
          if (programId == null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(child: _modeToggle()),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: MuscleMapControls(
                view: _view,
                onViewChanged: (v) => setState(() => _view = v),
                figure: figure,
                onFigureChanged: (f) => ref.read(mapFigureChoiceProvider.notifier).choose(f),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.45,
                child: MuscleMapCard(
                  child: MuscleMap(
                    view: _view,
                    figure: figure,
                    selected: muscle,
                    heat: heat,
                    onSelected: (m) => setState(() => _muscle = m),
                  ),
                ),
              ),
            ),
          ),
          if (_showsHeat)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _heatBar()),
            ),
          if (muscle == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  noWorkouts
                      ? 'workout.muscle_map.heat_empty'.tr(namedArgs: {'n': '$_days'})
                      : 'workout.muscle_map.hint'.tr(),
                  key: Key(noWorkouts ? 'muscle_heat_empty' : 'muscle_map_hint'),
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ),
            )
          else if (_showsHeat)
            ..._heatResults(context, muscle)
          else
            ..._results(context, muscle),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return SegmentedButton<bool>(
      key: const Key('muscle_map_mode_toggle'),
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      segments: [
        ButtonSegment(
          value: false,
          label: Text('workout.muscle_map.mode_explore'.tr(), key: const Key('muscle_map_mode_explore')),
        ),
        ButtonSegment(
          value: true,
          label: Text('workout.muscle_map.mode_heat'.tr(), key: const Key('muscle_map_mode_heat')),
        ),
      ],
      selected: {_heatMode},
      onSelectionChanged: (selection) => setState(() => _heatMode = selection.first),
    );
  }

  /// Solda 7/30 GÜN (program modunda yok), sağda lejant.
  Widget _heatBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.programId == null)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                key: const Key('muscle_heat_period_toggle'),
                showSelectedIcon: false,
                segments: [
                  for (final days in const [7, 30])
                    ButtonSegment(
                      value: days,
                      label: Text(
                        'workout.muscle_map.period_days'.tr(namedArgs: {'n': '$days'}),
                        key: Key('muscle_heat_period_$days'),
                      ),
                    ),
                ],
                selected: {_days},
                onSelectionChanged: (selection) => setState(() => _days = selection.first),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        const SizedBox(width: 12),
        const HeatLegend(),
      ],
    );
  }

  static const _loading = [
    SliverToBoxAdapter(
      child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    ),
  ];

  List<Widget> _retry(Key key, VoidCallback onPressed) {
    return [
      SliverToBoxAdapter(
        child: Center(
          child: TextButton(key: key, onPressed: onPressed, child: Text('workout.picker_load_error'.tr())),
        ),
      ),
    ];
  }

  List<Widget> _results(BuildContext context, String muscle) {
    return ref.watch(exercisesProvider).when(
          loading: () => _loading,
          error: (error, stackTrace) =>
              _retry(const Key('muscle_map_retry'), () => ref.invalidate(exercisesProvider)),
          data: (all) {
            final list = exercisesForMuscle(all, muscle, includeSecondary: _includeSecondary);
            return [
              SliverToBoxAdapter(
                child: _header(
                  context,
                  muscle,
                  infoKey: const Key('muscle_map_count'),
                  info: 'workout.muscle_map.count'.tr(namedArgs: {'n': '${list.length}'}),
                  trailing: AccentChip(
                    key: const Key('muscle_map_secondary_chip'),
                    label: 'workout.muscle_map.include_secondary'.tr(),
                    selected: _includeSecondary,
                    onSelected: (on) => setState(() => _includeSecondary = on),
                  ),
                ),
              ),
              if (list.isEmpty)
                _emptySliver(context, const Key('muscle_map_empty'), 'workout.muscle_map.empty'.tr())
              else
                _listCard(context, list.length, (index) => _row(context, list[index])),
            ];
          },
        );
  }

  List<Widget> _heatResults(BuildContext context, String muscle) {
    final programId = widget.programId;
    if (programId != null) {
      return ref.watch(programHeatProvider(programId)).when(
            loading: () => _loading,
            error: (error, stackTrace) => _retry(const Key('muscle_heat_retry'), () {
              ref.invalidate(programDetailProvider(programId));
              ref.invalidate(exercisesProvider);
            }),
            data: (heat) => _heatList(
              context,
              muscle,
              summary: 'workout.muscle_map.heat_summary_program'.tr(
                namedArgs: {'sets': formatSets(heat.load[muscle] ?? 0)},
              ),
              rows: programLoadsForMuscle(heat.program, heat.exercisesById, muscle),
              emptyKey: const Key('muscle_heat_program_muscle_empty'),
              emptyText: 'workout.muscle_map.heat_program_muscle_empty'.tr(),
            ),
          );
    }
    return ref.watch(historyHeatProvider(_days)).when(
          loading: () => _loading,
          error: (error, stackTrace) => _retry(const Key('muscle_heat_retry'), () {
            ref.invalidate(sessionHistoryProvider);
            ref.invalidate(exercisesProvider);
          }),
          data: (heat) => _heatList(
            context,
            muscle,
            summary: 'workout.muscle_map.heat_summary'.tr(
              namedArgs: {'sets': formatSets(heat.load[muscle] ?? 0), 'n': '$_days'},
            ),
            rows: historyLoadsForMuscle(heat.sessions, heat.exercisesById, heat.since, muscle),
            emptyKey: const Key('muscle_heat_muscle_empty'),
            emptyText: 'workout.muscle_map.heat_muscle_empty'.tr(namedArgs: {'n': '$_days'}),
          ),
        );
  }

  List<Widget> _heatList(
    BuildContext context,
    String muscle, {
    required String summary,
    required List<ExerciseLoad> rows,
    required Key emptyKey,
    required String emptyText,
  }) {
    return [
      SliverToBoxAdapter(child: _header(context, muscle, infoKey: const Key('muscle_heat_summary'), info: summary)),
      if (rows.isEmpty)
        _emptySliver(context, emptyKey, emptyText)
      else
        _listCard(context, rows.length, (index) => _heatRow(context, rows[index])),
    ];
  }

  Widget _emptySliver(BuildContext context, Key key, String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          key: key,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _listCard(BuildContext context, int count, Widget Function(int index) row) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        sliver: SliverList.separated(
          itemCount: count,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, index) => row(index),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String muscle, {required Key infoKey, required String info, Widget? trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  upperCaseFor(muscleLabelKey(muscle).tr(), context.locale.languageCode),
                  key: const Key('muscle_map_selected'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(info, key: infoKey, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Exercise e) {
    final subtitle = [
      if (e.equipment case final equipment?) equipmentLabelKey(equipment).tr(),
      if (_levelKey(e.level) case final level?) level.tr(),
      if (e.isCustom) 'workout.custom_exercise_badge'.tr(),
    ].join(' · ');
    return ListTile(
      key: Key('muscle_map_exercise_${e.id}'),
      leading: ExerciseIconBadge(equipment: e.equipment),
      title: Text(e.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showExerciseDetailSheet(context, e, selectable: false),
    );
  }

  Widget _heatRow(BuildContext context, ExerciseLoad load) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('muscle_heat_row_${load.exercise.id}'),
      leading: ExerciseIconBadge(equipment: load.exercise.equipment),
      title: Text(load.exercise.name),
      subtitle: Text((load.primary ? 'workout.muscle_map.primary' : 'workout.muscle_map.secondary').tr()),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: scheme.primary),
        ),
        child: Text(
          'workout.muscle_map.heat_row_sets'.tr(namedArgs: {'n': '${load.sets}'}),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
      ),
      onTap: () => showExerciseDetailSheet(context, load.exercise, selectable: false),
    );
  }
}

String? _levelKey(String? level) => switch (level) {
      'beginner' => 'workout.level_beginner',
      'intermediate' => 'workout.level_intermediate',
      'expert' => 'workout.level_advanced',
      _ => null,
    };
