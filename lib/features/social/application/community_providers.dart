import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../data/social_repository.dart';
import '../domain/community.dart';
import '../domain/period_keys.dart';
import '../domain/period_stats.dart';
import '../domain/public_profile.dart';
import '../domain/standings.dart';
import 'social_providers.dart';

/// "Topluluklarım" satırı (S2 spec §6.2).
class CommunityEntry {
  const CommunityEntry({required this.community, required this.memberCount, this.myPosition});

  final Community community;
  final int memberCount;

  /// Bu haftaki sıram; sıralamada yoksam null.
  final int? myPosition;
}

/// Üyesi olduğum topluluklar, ada göre; kimlik yoksa boş.
final myCommunitiesProvider = FutureProvider.autoDispose<List<CommunityEntry>>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const [];
  final repo = ref.watch(socialRepositoryProvider);
  final ids = await repo.fetchMyCommunityIds();
  final (communities, members) = await (repo.fetchCommunities(ids), repo.fetchMembers(ids)).wait;
  final stats = await repo.fetchPeriodStats([
    ...{
      for (final list in members.values)
        for (final m in list) m.userId,
    },
  ]);
  final key = periodKey(PeriodKind.week, ref.read(nowProvider)());
  final entries = <CommunityEntry>[];
  for (final community in communities) {
    final list = members[community.id] ?? const <CommunityMember>[];
    final memberStats = {
      for (final m in list)
        if (stats[m.userId] case final s?) m.userId: s,
    };
    final mine = standings(memberStats, PeriodKind.week, key).where((s) => s.userId == me.userId).firstOrNull;
    entries.add(CommunityEntry(community: community, memberCount: list.length, myPosition: mine?.position));
  }
  return entries..sort((a, b) => a.community.name.toLowerCase().compareTo(b.community.name.toLowerCase()));
});

class CommunityDetail {
  const CommunityDetail({
    required this.community,
    required this.members,
    required this.profiles,
    required this.stats,
    required this.myId,
  });

  final Community community;

  /// Katılma sırasıyla.
  final List<CommunityMember> members;

  /// Kendi profilim dahil.
  final Map<String, PublicProfile> profiles;

  /// Yayın yapmamış üye yok.
  final Map<String, PeriodStats> stats;
  final String myId;

  bool get iAmOwner => community.owner == myId;
}

/// Üye değilsem (ya da topluluk yoksa) null.
final communityDetailProvider = FutureProvider.autoDispose.family<CommunityDetail?, String>((ref, id) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return null;
  final repo = ref.watch(socialRepositoryProvider);
  final (communities, members) = await (repo.fetchCommunities([id]), repo.fetchMembers([id])).wait;
  final community = communities.firstOrNull;
  final list = members[id] ?? const <CommunityMember>[];
  if (community == null || !list.any((m) => m.userId == me.userId)) return null;
  final ids = [for (final m in list) m.userId];
  final (profiles, stats) = await (repo.fetchProfiles(ids), repo.fetchPeriodStats(ids)).wait;
  return CommunityDetail(
    community: community,
    members: list,
    profiles: {for (final p in profiles) p.userId: p, me.userId: me},
    stats: stats,
    myId: me.userId,
  );
});

class GlobalBoard {
  const GlobalBoard({this.titles = const [], this.rows = const []});

  /// Geçen dönemin genel unvanları.
  final List<GlobalTitle> titles;

  /// Bu dönemin ilk 50'si.
  final List<GlobalRow> rows;
}

final globalBoardProvider = FutureProvider.autoDispose.family<GlobalBoard, PeriodKind>((ref, kind) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const GlobalBoard();
  final repo = ref.watch(socialRepositoryProvider);
  final now = ref.read(nowProvider)();
  final (titles, rows) = await (
    repo.globalTitles(kind, periodKey(kind, now, previous: true)),
    repo.globalLeaderboard(kind, periodKey(kind, now)),
  ).wait;
  return GlobalBoard(titles: titles, rows: rows);
});

/// Topluluk yazma işlemleri; her biri ilgili sağlayıcıları yeniler.
class CommunityActions {
  CommunityActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  void _refresh(String id) {
    _ref.invalidate(myCommunitiesProvider);
    _ref.invalidate(communityDetailProvider(id));
  }

  Future<String> create({required String name, required String description, required bool isPublic}) async {
    final id = await _repo.createCommunity(name: name, description: description, isPublic: isPublic);
    _refresh(id);
    return id;
  }

  Future<void> join(String id) async {
    await _repo.joinCommunity(id);
    _refresh(id);
  }

  Future<String> joinByCode(String code) async {
    final id = await _repo.joinCommunityByCode(code);
    _refresh(id);
    return id;
  }

  Future<void> leave(String id) async {
    await _repo.leaveCommunity(id);
    _refresh(id);
  }

  Future<void> update(String id, {String? name, String? description, bool? isPublic}) async {
    await _repo.updateCommunity(id, name: name, description: description, isPublic: isPublic);
    _refresh(id);
  }

  Future<void> removeMember(String communityId, String userId, {required bool ban}) async {
    await _repo.removeMember(communityId, userId, ban: ban);
    _refresh(communityId);
  }

  Future<String> regenerateCode(String id) async {
    final code = await _repo.regenerateCommunityCode(id);
    _refresh(id);
    return code;
  }
}

final communityActionsProvider = Provider<CommunityActions>(CommunityActions.new);
