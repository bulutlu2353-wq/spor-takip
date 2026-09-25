import '../domain/program.dart';
import '../domain/schedule_mode.dart';

enum EditorValidationError { emptyName, emptyWorkoutName, missingWeekday }

class ProgramEditorState {
  const ProgramEditorState({this.draft, this.dirty = false, this.saving = false, this.saveFailed = false});

  /// null = düzenlenecek program henüz yüklenmedi.
  final Program? draft;
  final bool dirty;
  final bool saving;
  final bool saveFailed;

  EditorValidationError? get validationError {
    final d = draft;
    if (d == null) return null;
    if (d.name.trim().isEmpty) return EditorValidationError.emptyName;
    if (d.workouts.any((w) => w.name.trim().isEmpty)) return EditorValidationError.emptyWorkoutName;
    if (d.scheduleMode == ScheduleMode.weekdays && d.workouts.any((w) => w.weekday == null)) {
      return EditorValidationError.missingWeekday;
    }
    return null;
  }

  ProgramEditorState copyWith({Program? draft, bool? dirty, bool? saving, bool? saveFailed}) {
    return ProgramEditorState(
      draft: draft ?? this.draft,
      dirty: dirty ?? this.dirty,
      saving: saving ?? this.saving,
      saveFailed: saveFailed ?? this.saveFailed,
    );
  }
}
