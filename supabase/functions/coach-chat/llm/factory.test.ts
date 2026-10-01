import { assertEquals, assertInstanceOf, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { createLlmClient } from './factory.ts';
import { GeminiClient } from './gemini_client.ts';

Deno.test('defaults to Gemini with the default model', async () => {
  let url = '';
  const fetchFn: typeof fetch = async (input) => {
    url = String(input);
    return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: 'ok' }] } }] }));
  };
  const client = createLlmClient({ geminiApiKey: 'KEY' }, fetchFn);
  assertInstanceOf(client, GeminiClient);
  await client.generate({ system: 's', messages: [{ role: 'user', text: 'x' }], tools: [] });
  assertEquals(url.includes('/models/gemini-3.5-flash-lite:generateContent'), true);
});

Deno.test('empty strings fall back to defaults', () => {
  assertInstanceOf(createLlmClient({ provider: '', model: '', geminiApiKey: 'KEY' }), GeminiClient);
});

Deno.test('rejects an unknown provider', () => {
  assertThrows(() => createLlmClient({ provider: 'acme', geminiApiKey: 'KEY' }), Error, 'acme');
});

Deno.test('requires the Gemini API key', () => {
  assertThrows(() => createLlmClient({ provider: 'gemini' }), Error, 'GEMINI_API_KEY');
});
