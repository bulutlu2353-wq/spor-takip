import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/workout_providers.dart';
import '../domain/program.dart';
import '../domain/program_level.dart';
import 'widgets/program_card.dart';

class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});

  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  static const _dayOptions = [3, 4, 5, 6];

  ProgramLevel? _level;
  int? _days;

  @override
  Widget build(BuildContext context) {
    final programsAsync = ref.watch(programsProvider);
    final activeId = ref.watch(activeProgramStateProvider).value?.programId;

    return Scaffold(
      key: const Key('programs_screen'),
      appBar: AppBar(title: Text('workout.programs_title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('programs_create_fab'),
        onPressed: () => context.push('/workout/new'),
        icon: const Icon(Icons.add),
        label: Text('workout.create_program'.tr()),
      ),
      body: programsAsync.when(
        data: (programs) => _buildList(context, programs, activeId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(programsProvider),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Program> programs, String? activeId) {
    final active = programs.where((p) => p.id == activeId).firstOrNull;
    final mine = programs.where((p) => !p.isBuiltIn).toList();
    final builtIn = programs
        .where((p) => p.isBuiltIn)
        .where((p) => _level == null || p.level == _level)
        .where((p) => _days == null || p.effectiveDaysPerWeek == _days)
        .toList();
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    void open(Program p) => context.push('/workout/program/${p.id}');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (active != null)
          Column(
            key: const Key('programs_active_section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('workout.active_program'.tr(), style: titleStyle),
              ProgramCard(program: active, isActive: true, onTap: () => open(active)),
              const SizedBox(height: 16),
            ],
          ),
        Text('workout.my_programs'.tr(), style: titleStyle),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('workout.no_my_programs'.tr()),
          ),
        for (final p in mine) ProgramCard(key: ValueKey('mine_${p.id}'), program: p, onTap: () => open(p)),
        const SizedBox(height: 16),
        Text('workout.built_in_programs'.tr(), style: titleStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('programs_level_filter_all'),
              label: Text('workout.filter_all'.tr()),
              selected: _level == null,
              onSelected: (_) => setState(() => _level = null),
            ),
            for (final level in ProgramLevel.values)
              ChoiceChip(
                key: Key('programs_level_filter_${level.name}'),
                label: Text('workout.level_${level.name}'.tr()),
                selected: _level == level,
                onSelected: (_) => setState(() => _level = level),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('programs_days_filter_all'),
              label: Text('workout.filter_all'.tr()),
              selected: _days == null,
              onSelected: (_) => setState(() => _days = null),
            ),
            for (final d in _dayOptions)
              ChoiceChip(
                key: Key('programs_days_filter_$d'),
                label: Text('workout.days_per_week'.tr(namedArgs: {'count': '$d'})),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
        if (builtIn.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('workout.no_filter_results'.tr()),
          ),
        for (final p in builtIn) ProgramCard(key: ValueKey('builtin_${p.id}'), program: p, onTap: () => open(p)),
      ],
    );
  }
}
