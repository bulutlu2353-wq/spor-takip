import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/community_providers.dart';
import '../application/social_providers.dart';
import '../domain/community.dart';
import '../domain/period_keys.dart';
import '../domain/standings.dart';
import 'widgets/period_widgets.dart';

/// Genel unvanlar kategori sırasıyla; eşitlikte sahipler @kullanıcıadı ile, gelen sırayla.
List<TitleLine> globalTitleLines(List<GlobalTitle> titles) {
  final lines = <TitleLine>[];
  for (final category in periodCategories) {
    final holders = [
      for (final t in titles)
        if (t.category == category) t,
    ];
    if (holders.isEmpty) continue;
    lines.add(TitleLine(
      category: category,
      holders: [for (final h in holders) '@${h.username}'],
      value: holders.first.value,
    ));
  }
  return lines;
}

/// Genel sekmesi (S2 spec §6.4): geçen dönemin genel şampiyonları ve bu dönemin ilk 50'si.
class GlobalTab extends ConsumerStatefulWidget {
  const GlobalTab({super.key});

  @override
  ConsumerState<GlobalTab> createState() => _GlobalTabState();
}

class _GlobalTabState extends ConsumerState<GlobalTab> {
  PeriodKind _kind = PeriodKind.week;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myPublicProfileProvider).value;
    final provider = globalBoardProvider(_kind);
    final async = ref.watch(provider);
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      child: ListView(
        key: const Key('global_tab'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PeriodSwitch(kind: _kind, keyPrefix: 'global_period', onChanged: (k) => setState(() => _kind = k)),
          if (me != null && !me.competeGlobally)
            Card(
              key: const Key('global_opted_out'),
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('social.global_opted_out'.tr())),
                    TextButton(
                      key: const Key('global_open_settings'),
                      onPressed: () => context.push('/social/settings'),
                      child: Text('social.global_open_settings'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ...async.when(
            loading: () => const [
              Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            ],
            error: (error, stackTrace) => [
              Center(
                child: TextButton(
                  key: const Key('global_retry'),
                  onPressed: () => ref.invalidate(provider),
                  child: Text('social.retry'.tr()),
                ),
              ),
            ],
            data: (board) => [
              SectionHeader('social.global_titles_${_kind.name}'.tr()),
              if (board.titles.isEmpty)
                Text('social.titles_empty'.tr(), key: const Key('global_titles_empty'), style: muted)
              else
                PeriodTitlesList(key: const Key('global_titles'), kind: _kind, lines: globalTitleLines(board.titles)),
              SectionHeader(
                'social.global_standings_${_kind.name}'.tr(),
                key: const Key('period_remaining'),
                trailing: periodRemainingLabel(_kind, ref.read(nowProvider)()),
              ),
              if (board.rows.isEmpty)
                Text('social.standings_empty'.tr(), key: const Key('global_standings_empty'), style: muted)
              else
                StandingsList(
                  key: const Key('global_standings'),
                  lines: [
                    for (final r in board.rows)
                      StandingLine(
                        userId: r.userId,
                        position: r.position,
                        name: r.displayName,
                        handle: r.username,
                        initials: r.initials,
                        level: r.level,
                        rank: r.rank,
                        xp: r.xp,
                        title: sharedTitleName(r.activeTitle),
                        isMe: r.userId == me?.userId,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
