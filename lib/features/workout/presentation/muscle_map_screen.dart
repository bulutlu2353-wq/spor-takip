import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text_case.dart';
import '../../../shared/widgets/accent_chip.dart';
import '../application/muscle_map_providers.dart';
import '../application/workout_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import '../domain/exercise_taxonomy.dart';
import '../domain/muscle_map.dart';
import 'widgets/exercise_detail_sheet.dart';
import 'widgets/exercise_icon_badge.dart';
import 'widgets/muscle_map.dart';

/// Kas haritası: kasa dokun → o kası çalıştıran hareketler (yalnız göz atma).
class MuscleMapScreen extends ConsumerStatefulWidget {
  const MuscleMapScreen({super.key});

  @override
  ConsumerState<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends ConsumerState<MuscleMapScreen> {
  BodyView _view = BodyView.front;
  String? _muscle;
  bool _includeSecondary = false;

  @override
  Widget build(BuildContext context) {
    final muscle = _muscle;
    final figure = ref.watch(mapFigureProvider);
    final lang = context.locale.languageCode;
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
                    onSelected: (m) => setState(() => _muscle = m),
                  ),
                ),
              ),
            ),
          ),
          if (muscle == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'workout.muscle_map.hint'.tr(),
                  key: const Key('muscle_map_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._results(context, muscle),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, String muscle) {
    return ref.watch(exercisesProvider).when(
          loading: () => const [
            SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            ),
          ],
          error: (error, stackTrace) => [
            SliverToBoxAdapter(
              child: Center(
                child: TextButton(
                  key: const Key('muscle_map_retry'),
                  onPressed: () => ref.invalidate(exercisesProvider),
                  child: Text('workout.picker_load_error'.tr()),
                ),
              ),
            ),
          ],
          data: (all) {
            final list = exercisesForMuscle(all, muscle, includeSecondary: _includeSecondary);
            return [
              SliverToBoxAdapter(child: _header(context, muscle, list.length)),
              if (list.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'workout.muscle_map.empty'.tr(),
                      key: const Key('muscle_map_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: DecoratedSliver(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 16),
                      itemBuilder: (context, index) => _row(context, list[index]),
                    ),
                  ),
                ),
            ];
          },
        );
  }

  Widget _header(BuildContext context, String muscle, int count) {
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
                  child: Text(
                    'workout.muscle_map.count'.tr(namedArgs: {'n': '$count'}),
                    key: const Key('muscle_map_count'),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AccentChip(
            key: const Key('muscle_map_secondary_chip'),
            label: 'workout.muscle_map.include_secondary'.tr(),
            selected: _includeSecondary,
            onSelected: (on) => setState(() => _includeSecondary = on),
          ),
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
}

/// Veritabanı seviyesi → çeviri anahtarı ('expert' → İleri); bilinmeyen/null atlanır.
String? _levelKey(String? level) => switch (level) {
      'beginner' => 'workout.level_beginner',
      'intermediate' => 'workout.level_intermediate',
      'expert' => 'workout.level_advanced',
      _ => null,
    };
