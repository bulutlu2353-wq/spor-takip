import { assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { handleChatRequest } from './handler.ts';
import type { ChatStore, HandlerDeps } from './handler.ts';
import { LlmQuotaError, LlmUnavailableError } from './llm/types.ts';
import type { LlmClient, LlmRequest, LlmResponse } from './llm/types.ts';
import { sampleContext } from './test_fixtures.ts';
import { TOOL_DEFINITIONS } from './tools.ts';
import type { ToolDeps } from './tools.ts';
import type { ContextData, NewEvent, StoredMessage, ToolName } from './types.ts';

class FakeStore implements ChatStore {
  used = 0;
  history: StoredMessage[] = [];
  since?: Date;
  historyLimit?: number;
  ranges: Array<{ today: string; dayStart: Date; dayEnd: Date }> = [];
  snapshots: Array<{ tool: ToolName; payload: Record<string, unknown> }> = [];
  saved: Array<{ userText: string; assistantText: string; event: NewEvent | null }> = [];

  countUsageSince(since: Date) {
    this.since = since;
    return Promise.resolve(this.used);
  }
  recentMessages(limit: number) {
    this.historyLimit = limit;
    return Promise.resolve(this.history);
  }
  loadContext(range: { today: string; dayStart: Date; dayEnd: Date }): Promise<ContextData> {
    this.ranges.push(range);
    return Promise.resolve(sampleContext());
  }
  targetSnapshot(tool: ToolName, payload: Record<string, unknown>) {
    this.snapshots.push({ tool, payload });
    return Promise.resolve({ snapshot: tool });
  }
  saveExchange(userText: string, assistantText: string, event: NewEvent | null): Promise<StoredMessage[]> {
    this.saved.push({ userText, assistantText, event });
    return Promise.resolve([
      { id: 'u', role: 'user', content: userText, created_at: 't1', event: null },
      { id: 'a', role: 'assistant', content: assistantText, created_at: 't2', event: event && { id: 'e1', status: 'pending', ...event } },
    ]);
  }
}

class ScriptedLlm implements LlmClient {
  requests: LlmRequest[] = [];
  constructor(private readonly responses: Array<LlmResponse | Error>) {}
  generate(req: LlmRequest): Promise<LlmResponse> {
    this.requests.push(structuredClone(req));
    const next = this.responses.shift();
    if (next === undefined) return Promise.reject(new Error('no scripted response'));
    return next instanceof Error ? Promise.reject(next) : Promise.resolve(next);
  }
}

const unusedTools: ToolDeps = {
  findExercises: () => Promise.resolve([]),
  exerciseNames: () => Promise.resolve({}),
  programSnapshot: () => Promise.resolve(null),
  findBestMatch: () => Promise.resolve(null),
  fetchMacrosPer100g: () => Promise.reject(new Error('unused')),
  newId: () => 'id',
};

const NOW = new Date('2026-09-30T22:30:00Z');

function setup(responses: Array<LlmResponse | Error>) {
  const store = new FakeStore();
  const llm = new ScriptedLlm(responses);
  const deps: HandlerDeps = { store, tools: unusedTools, llm, dailyLimit: 30, now: () => NOW };
  return { store, llm, deps };
}

const request = { message: '  Bugün ne yemeliyim?  ', locale: 'tr', utc_offset_minutes: 180 };

Deno.test('status returns the remaining quota without calling the model', async () => {
  const { store, llm, deps } = setup([]);
  store.used = 5;
  assertEquals(await handleChatRequest({ action: 'status' }, deps), { status: 200, body: { remaining: 25 } });
  assertEquals(store.since, new Date('2026-09-29T22:30:00Z'));
  assertEquals(llm.requests.length, 0);
});

Deno.test('rejects an empty or too long message', async () => {
  const { deps } = setup([]);
  assertEquals((await handleChatRequest({ message: '   ' }, deps)).status, 400);
  assertEquals((await handleChatRequest({ message: 'x'.repeat(2001) }, deps)).status, 400);
});

Deno.test('daily limit stops the request before the model', async () => {
  const { store, llm, deps } = setup([]);
  store.used = 30;
  const result = await handleChatRequest(request, deps);
  assertEquals(result, { status: 429, body: { code: 'DAILY_LIMIT', message: 'Günlük mesaj hakkı doldu', remaining: 0 } });
  assertEquals(llm.requests.length, 0);
  assertEquals(store.saved.length, 0);
});

Deno.test('a text reply is saved with the trimmed message and the remaining quota drops', async () => {
  const { store, llm, deps } = setup([{ type: 'text', text: 'Protein ağırlıklı bir akşam yemeği öneririm.' }]);
  const result = await handleChatRequest(request, deps);

  assertEquals(result.status, 200);
  assertEquals((result.body as { remaining: number }).remaining, 29);
  assertEquals(store.saved, [{ userText: 'Bugün ne yemeliyim?', assistantText: 'Protein ağırlıklı bir akşam yemeği öneririm.', event: null }]);
  assertEquals(store.historyLimit, 20);
  assertEquals(store.ranges, [{ today: '2026-10-01', dayStart: new Date('2026-09-30T21:00:00Z'), dayEnd: new Date('2026-10-01T21:00:00Z') }]);

  const sent = llm.requests[0];
  assertStringIncludes(sent.system, 'Always reply in Turkish.');
  assertStringIncludes(sent.system, '## Active program: My 5x5');
  assertEquals(sent.messages.at(-1), { role: 'user', text: 'Bugün ne yemeliyim?' });
  assertEquals(sent.tools, TOOL_DEFINITIONS);
});

Deno.test('history is passed before the new message', async () => {
  const { store, llm, deps } = setup([{ type: 'text', text: 'ok' }]);
  store.history = [
    { id: '1', role: 'user', content: 'selam', created_at: 't', event: null },
    { id: '2', role: 'assistant', content: 'merhaba', created_at: 't', event: null },
  ];
  await handleChatRequest(request, deps);
  assertEquals(llm.requests[0].messages.slice(0, 2), [{ role: 'user', text: 'selam' }, { role: 'assistant', text: 'merhaba' }]);
});

Deno.test('a valid tool call becomes a pending event with a base snapshot', async () => {
  const { store, deps } = setup([{ type: 'tool_call', name: 'set_goal', args: { goal: 'lose_weight' }, text: '' }]);
  const result = await handleChatRequest({ ...request, message: 'kilo vermek istiyorum' }, deps);

  assertEquals(result.status, 200);
  assertEquals(store.snapshots, [{ tool: 'set_goal', payload: { goal: 'lose_weight' } }]);
  assertEquals(store.saved[0], {
    userText: 'kilo vermek istiyorum',
    assistantText: 'Amaç değişikliği: Kilo vermek',
    event: { tool: 'set_goal', summary: 'Amaç değişikliği: Kilo vermek', payload: { goal: 'lose_weight' }, base: { snapshot: 'set_goal' } },
  });
});

Deno.test('the model text accompanies the card when present', async () => {
  const { store, deps } = setup([{ type: 'tool_call', name: 'set_goal', args: { goal: 'maintain' }, text: 'Şunu önereyim:' }]);
  await handleChatRequest(request, deps);
  assertEquals(store.saved[0].assistantText, 'Şunu önereyim:');
});

Deno.test('an invalid tool call is sent back to the model with the error, then corrected', async () => {
  const raw = { functionCall: { name: 'set_goal', args: { goal: 'gain_muscle' } }, thoughtSignature: 'SIG' };
  const { store, llm, deps } = setup([
    { type: 'tool_call', name: 'set_goal', args: { goal: 'gain_muscle' }, text: '', raw },
    { type: 'tool_call', name: 'set_goal', args: { goal: 'maintain' }, text: '' },
  ]);
  await handleChatRequest(request, deps);

  assertEquals(llm.requests.length, 2);
  assertEquals(llm.requests[1].messages.slice(-2), [
    { role: 'assistant_tool_call', name: 'set_goal', args: { goal: 'gain_muscle' }, raw },
    { role: 'tool_result', name: 'set_goal', result: { error: 'goal is already gain_muscle', candidates: [] } },
  ]);
  assertEquals(store.saved[0].event?.payload, { goal: 'maintain' });
});

Deno.test('after three invalid calls a fixed reply is saved without an event', async () => {
  const bad: LlmResponse = { type: 'tool_call', name: 'set_goal', args: { goal: 'fly' }, text: '' };
  const { store, llm, deps } = setup([bad, bad, bad, { type: 'text', text: 'never used' }]);
  await handleChatRequest({ ...request, locale: 'en' }, deps);

  assertEquals(llm.requests.length, 3);
  assertEquals(store.saved, [{
    userText: 'Bugün ne yemeliyim?',
    assistantText: "I couldn't quite understand that. Could you say it a bit more clearly?",
    event: null,
  }]);
});

Deno.test('model quota and availability errors map to 429 and 503 and save nothing', async () => {
  const quota = setup([new LlmQuotaError('quota')]);
  assertEquals(await handleChatRequest(request, quota.deps), {
    status: 429, body: { code: 'LLM_QUOTA', message: 'Antrenör şu an çok yoğun' },
  });
  assertEquals(quota.store.saved.length, 0);

  const down = setup([new LlmUnavailableError('down')]);
  assertEquals(await handleChatRequest(request, down.deps), {
    status: 503, body: { code: 'LLM_UNAVAILABLE', message: 'Antrenöre şu an ulaşılamıyor' },
  });
  assertEquals(down.store.saved.length, 0);
});
