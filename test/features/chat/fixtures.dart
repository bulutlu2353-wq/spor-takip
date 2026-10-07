import 'package:spor_takip/features/chat/domain/chat_models.dart';

const _targets = {'daily_calorie_target': 2700, 'daily_protein_target_g': 176};

/// Profil kilosu 80; [logBefore] o tarihteki eski kayıt.
ChatEvent weightEvent({
  String date = '2026-10-01',
  num kg = 82,
  num? logBefore,
  ChatEventStatus status = ChatEventStatus.pending,
}) {
  return ChatEvent(
    id: 'e-weight',
    tool: ChatTool.logBodyWeight,
    status: status,
    summary: 'Kilo kaydı: $kg kg ($date)',
    payload: {'date': date, 'kg': kg},
    base: {
      'log': logBefore,
      'profile': {'weight_kg': 80, ..._targets},
    },
  );
}

ChatEvent profileEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-profile',
    tool: ChatTool.updateProfile,
    status: status,
    summary: 'Profil güncelleme: boy, aktivite',
    payload: {
      'changes': {'height_cm': 185, 'activity_level': 'active'},
    },
    base: {'activity_level': 'moderate', 'height_cm': 180, ..._targets},
  );
}

ChatEvent goalEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-goal',
    tool: ChatTool.setGoal,
    status: status,
    summary: 'Amaç değişikliği: Kilo vermek (dengeli) · Kas',
    payload: {'weight_direction': 'lose', 'pace': 'balanced', 'focuses': ['muscle']},
    base: {'weight_direction': 'maintain', 'pace': null, 'focuses': ['muscle'], ..._targets},
  );
}

/// G1 öncesi kaydedilmiş, tek `goal` alanlı olay.
ChatEvent legacyGoalEvent({ChatEventStatus status = ChatEventStatus.applied}) {
  return ChatEvent(
    id: 'e-legacy-goal',
    tool: ChatTool.setGoal,
    status: status,
    summary: 'Amaç değişikliği: Kilo vermek',
    payload: {'goal': 'lose_weight'},
    base: {'goal': 'gain_muscle', ..._targets},
  );
}

ChatEvent mealEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-meal',
    tool: ChatTool.createMeal,
    status: status,
    summary: 'Öğün: Öğle — Tavuk (200 g), Ayran (200 g)',
    payload: {
      'meal_id': 'meal-1',
      'meal_type': 'lunch',
      'logged_at': '2026-10-01T09:30:00.000Z',
      'items': [
        {
          'name': 'Tavuk',
          'grams': 200,
          'per100': {'calories': 165, 'protein_g': 31, 'carbs_g': 0, 'fat_g': 3.6},
          'usda_fdc_id': '171077',
          'needs_review': false,
        },
        {
          'name': 'Ayran',
          'grams': 200,
          'per100': {'calories': 0, 'protein_g': 0, 'carbs_g': 0, 'fat_g': 0},
          'usda_fdc_id': null,
          'needs_review': true,
        },
      ],
    },
    base: {'meal': null},
  );
}

ChatEvent setEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-set',
    tool: ChatTool.logSet,
    status: status,
    summary: 'Set kaydı: Barbell Squat 3. set — 80 kg × 5',
    payload: {
      'session_id': 'session-1',
      'exercise_position': 0,
      'set_index': 2,
      'weight_kg': 80,
      'reps': 5,
      'exercise_name': 'Barbell Squat',
      'set_number': 3,
    },
    base: {
      'set': {'weight_kg': null, 'reps': null, 'completed_at': null, 'finished_at': null},
    },
  );
}

ChatEvent programEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-program',
    tool: ChatTool.editProgram,
    status: status,
    summary: 'Program düzenleme: My 5x5 (2 değişiklik)',
    payload: {
      'program_id': 'prog-1',
      'program': {'id': 'prog-1', 'name': 'My 5x5', 'workouts': []},
      'changes': [
        {'kind': 'add', 'label': '+ A: Barbell Deadlift 1×5'},
        {'kind': 'remove', 'label': '− A: Barbell Squat'},
      ],
    },
    base: {
      'program': {'id': 'prog-1'},
    },
  );
}

ChatMessage userMessage(String content, {String id = 'u1'}) {
  return ChatMessage(id: id, role: ChatRole.user, content: content, createdAt: DateTime.utc(2026, 10, 1, 9));
}

ChatMessage assistantMessage(ChatEvent? event, {String id = 'a1', String content = 'Kaydedeyim mi?'}) {
  return ChatMessage(
    id: id,
    role: ChatRole.assistant,
    content: content,
    createdAt: DateTime.utc(2026, 10, 1, 9, 1),
    event: event,
  );
}
