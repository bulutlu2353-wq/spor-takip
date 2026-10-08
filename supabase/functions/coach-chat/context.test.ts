import { assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { buildContextText, historyToLlmMessages, localDate } from './context.ts';
import { fallbackReply, systemPrompt } from './prompts.ts';
import { sampleContext } from './test_fixtures.ts';
import type { StoredMessage } from './types.ts';

Deno.test('localDate uses the device offset', () => {
  assertEquals(localDate(new Date('2026-09-30T22:30:00Z'), 180), '2026-10-01');
  assertEquals(localDate(new Date('2026-09-30T22:30:00Z'), 0), '2026-09-30');
});

Deno.test('context lists profile, targets and today meals with local times and totals', () => {
  const text = buildContextText(sampleContext(), 180);
  assertStringIncludes(text, 'weight_kg: 80, height_cm: 180, birth_year: 1996, gender: male');
  assertStringIncludes(text, 'goal: maintain, focuses: muscle, daily_calorie_target: 2700 kcal, daily_protein_target_g: 176');
  assertStringIncludes(text, "## Today's meals (2026-10-01)");
  assertStringIncludes(text, '- lunch 12:30: Tavuk 200 g, Pilav 150 g (525 kcal)');
  assertStringIncludes(text, 'totals: 525 kcal, protein 66.1 g, carbs 42 g, fat 7.7 g');
});

Deno.test('context shows weights, best set per exercise and the 1RMs', () => {
  const text = buildContextText(sampleContext(), 180);
  assertStringIncludes(text, '2026-09-20: 80.5, 2026-09-30: 80');
  assertStringIncludes(text, '- 2026-09-30 A: Barbell Squat 105x3, Pullups bodyweightx8');
  assertStringIncludes(text, 'Barbell Squat: 120 kg');
});

Deno.test('context marks the active program as editable and lists the in-progress sets', () => {
  const text = buildContextText(sampleContext(), 180);
  assertStringIncludes(text, '## Active program: My 5x5 (own, editable)');
  assertStringIncludes(text, '- A: Barbell Squat 5x5, Barbell Bench Press - Medium Grip 3x8-12');
  assertStringIncludes(text, '## In-progress workout: A');
  assertStringIncludes(text, '- Barbell Squat set 1: target 5, done 100 kg x 5');
  assertStringIncludes(text, '- Barbell Squat set 2: target 5, not done');
});

Deno.test('context handles missing data', () => {
  const data = { ...sampleContext(), todayMeals: [], weights: [], recentSessions: [], oneRepMaxes: [], inProgress: null };
  data.activeProgram = { ...data.activeProgram!, is_builtin: true };
  const text = buildContextText(data, 0);
  assertStringIncludes(text, 'none logged');
  assertStringIncludes(text, '(built-in, read-only)');
  assertStringIncludes(text, '## In-progress workout: none');
  assertEquals(buildContextText({ ...data, activeProgram: null }, 0).includes('## Active program: none'), true);
});

Deno.test('history keeps roles and annotates proposal cards with their status', () => {
  const history: StoredMessage[] = [
    { id: '1', role: 'user', content: 'kilom 82', created_at: 't1', event: null },
    {
      id: '2', role: 'assistant', content: 'Kaydedeyim mi?', created_at: 't2',
      event: { id: 'e', tool: 'log_body_weight', status: 'cancelled', summary: 'Kilo kaydı: 82 kg (2026-10-01)', payload: {}, base: {} },
    },
  ];
  assertEquals(historyToLlmMessages(history), [
    { role: 'user', text: 'kilom 82' },
    { role: 'assistant', text: 'Kaydedeyim mi?\nKilo kaydı: 82 kg (2026-10-01) [user declined the change]' },
  ]);
});

Deno.test('system prompt sets the reply language and embeds the context', () => {
  assertStringIncludes(systemPrompt('tr', 'CTX'), 'Always reply in Turkish.');
  assertStringIncludes(systemPrompt('en', 'CTX'), 'Always reply in English.');
  assertStringIncludes(systemPrompt('tr', 'CTX'), '# User data\nCTX');
  assertEquals(fallbackReply('tr'), 'Bunu tam anlayamadım, biraz daha açık yazar mısın?');
  assertEquals(fallbackReply('en'), "I couldn't quite understand that. Could you say it a bit more clearly?");
});

Deno.test('context shows a non-zero calorie adjustment', () => {
  const data = sampleContext();
  data.profile!.calorie_adjustment_kcal = -160.4;
  const text = buildContextText(data, 180);
  assertStringIncludes(text, 'daily_protein_target_g: 176, calorie_adjustment_kcal: -160 (already included in the target)');
});
