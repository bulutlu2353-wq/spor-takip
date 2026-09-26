import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_providers.dart';
import '../application/start_session_service.dart';
import '../domain/program.dart';

enum _Conflict { resume, replace }

/// Antrenmanı başlatıp oturum ekranını açar. Devam eden oturum varsa önce
/// "Devam et / İptal et, yenisini başlat / Vazgeç" sorulur. Hata fırlatır;
/// çağıran yakalayıp kullanıcıya gösterir.
Future<void> startWorkout(BuildContext context, WidgetRef ref, Program program, int workoutIndex) async {
  final existing = await ref.read(sessionRepositoryProvider).fetchInProgressSession();
  if (!context.mounted) return;
  if (existing != null) {
    final choice = await showDialog<_Conflict>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.session.conflict_title'.tr()),
        content: Text(existing.workoutName),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('session_conflict_replace'),
            onPressed: () => Navigator.of(dialogContext).pop(_Conflict.replace),
            child: Text('workout.session.conflict_replace'.tr()),
          ),
          FilledButton(
            key: const Key('session_conflict_resume'),
            onPressed: () => Navigator.of(dialogContext).pop(_Conflict.resume),
            child: Text('workout.session.resume'.tr()),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _Conflict.resume) {
      context.push('/session/${existing.id}');
      return;
    }
    await ref.read(sessionRepositoryProvider).deleteSession(existing.id);
  }
  final id = await ref.read(startSessionServiceProvider).start(program, workoutIndex);
  if (context.mounted) context.push('/session/$id');
}
