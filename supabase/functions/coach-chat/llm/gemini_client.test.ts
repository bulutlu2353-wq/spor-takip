import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { GeminiClient } from './gemini_client.ts';
import { LlmQuotaError, LlmUnavailableError } from './types.ts';
import type { LlmRequest } from './types.ts';

function capture(response: Response | (() => Promise<Response>)) {
  const calls: Array<{ url: string; body: Record<string, unknown> }> = [];
  const fetchFn: typeof fetch = async (input, init) => {
    calls.push({ url: String(input), body: JSON.parse(String(init?.body)) });
    return typeof response === 'function' ? await response() : response.clone();
  };
  return { calls, fetchFn };
}

function geminiResponse(parts: unknown[]): Response {
  return new Response(JSON.stringify({ candidates: [{ content: { role: 'model', parts } }] }), { status: 200 });
}

const tool = { name: 'set_goal', description: 'd', parameters: { type: 'object', properties: {} } };

const baseRequest: LlmRequest = {
  system: 'SYSTEM',
  messages: [
    { role: 'user', text: 'merhaba' },
    { role: 'assistant', text: 'selam' },
    { role: 'user', text: 'amacım kilo vermek' },
  ],
  tools: [tool],
};

Deno.test('sends system instruction, mapped contents and function declarations', async () => {
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'Tamam' }]));
  await new GeminiClient('KEY', 'gemini-test', fetchFn).generate(baseRequest);

  assertEquals(calls[0].url, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent?key=KEY');
  assertEquals(calls[0].body.systemInstruction, { parts: [{ text: 'SYSTEM' }] });
  assertEquals(calls[0].body.contents, [
    { role: 'user', parts: [{ text: 'merhaba' }] },
    { role: 'model', parts: [{ text: 'selam' }] },
    { role: 'user', parts: [{ text: 'amacım kilo vermek' }] },
  ]);
  assertEquals(calls[0].body.tools, [{ functionDeclarations: [tool] }]);
});

Deno.test('omits tools when none are given', async () => {
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'Tamam' }]));
  await new GeminiClient('KEY', 'm', fetchFn).generate({ ...baseRequest, tools: [] });
  assertEquals('tools' in calls[0].body, false);
});

Deno.test('parses a text reply, skipping thought parts', async () => {
  const { fetchFn } = capture(geminiResponse([{ text: 'düşünce', thought: true }, { text: 'Merhaba ' }, { text: 'dünya' }]));
  const res = await new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest);
  assertEquals(res, { type: 'text', text: 'Merhaba dünya' });
});

Deno.test('parses a function call and keeps the raw part (thought signature)', async () => {
  const part = { functionCall: { name: 'set_goal', args: { goal: 'lose_weight' } }, thoughtSignature: 'SIG' };
  const { fetchFn } = capture(geminiResponse([{ text: 'Önereyim:' }, part]));
  const res = await new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest);
  assertEquals(res, { type: 'tool_call', name: 'set_goal', args: { goal: 'lose_weight' }, text: 'Önereyim:', raw: part });
});

Deno.test('re-sends a tool call raw part and maps tool results to functionResponse', async () => {
  const part = { functionCall: { name: 'set_goal', args: { goal: 'x' } }, thoughtSignature: 'SIG' };
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'ok' }]));
  await new GeminiClient('KEY', 'm', fetchFn).generate({
    ...baseRequest,
    messages: [
      { role: 'user', text: 'hedef' },
      { role: 'assistant_tool_call', name: 'set_goal', args: { goal: 'x' }, raw: part },
      { role: 'tool_result', name: 'set_goal', result: { error: 'invalid goal' } },
    ],
  });
  assertEquals((calls[0].body.contents as unknown[]).slice(1), [
    { role: 'model', parts: [part] },
    { role: 'user', parts: [{ functionResponse: { name: 'set_goal', response: { error: 'invalid goal' } } }] },
  ]);
});

Deno.test('builds a functionCall part when no raw part is available', async () => {
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'ok' }]));
  await new GeminiClient('KEY', 'm', fetchFn).generate({
    ...baseRequest,
    messages: [{ role: 'assistant_tool_call', name: 'set_goal', args: { goal: 'x' } }],
  });
  assertEquals(calls[0].body.contents, [{ role: 'model', parts: [{ functionCall: { name: 'set_goal', args: { goal: 'x' } } }] }]);
});

Deno.test('maps HTTP 429 to LlmQuotaError', async () => {
  const { fetchFn } = capture(new Response('quota', { status: 429 }));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmQuotaError);
});

Deno.test('maps other HTTP errors to LlmUnavailableError', async () => {
  const { fetchFn } = capture(new Response('boom', { status: 503 }));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmUnavailableError);
});

Deno.test('maps network failures to LlmUnavailableError', async () => {
  const { fetchFn } = capture(() => Promise.reject(new TypeError('network')));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmUnavailableError);
});

Deno.test('treats an empty reply as unavailable', async () => {
  const { fetchFn } = capture(geminiResponse([]));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmUnavailableError);
});
