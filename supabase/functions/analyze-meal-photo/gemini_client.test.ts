import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { GeminiQuotaExceededError, GeminiUnavailableError, identifyFoodItems } from './gemini_client.ts';

function jsonTextResponse(
  items: Array<{ name: string; estimated_grams: number; usda_query: string }>,
): Response {
  return new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ text: JSON.stringify({ items }) }] } }],
    }),
    { status: 200 },
  );
}

Deno.test('identifyFoodItems parses the model JSON response into predictions', async () => {
  const fakeFetch: typeof fetch = async () =>
    jsonTextResponse([
      { name: 'Izgara tavuk göğsü', estimated_grams: 150, usda_query: 'grilled chicken breast' },
      { name: 'Pilav', estimated_grams: 100, usda_query: 'white rice' },
    ]);

  const predictions = await identifyFoodItems(new Uint8Array([1, 2, 3]), 'fake-key', fakeFetch);

  assertEquals(predictions.length, 2);
  assertEquals(predictions[0].name, 'Izgara tavuk göğsü');
  assertEquals(predictions[0].estimatedGrams, 150);
  assertEquals(predictions[0].usdaQuery, 'grilled chicken breast');
});

Deno.test('identifyFoodItems throws GeminiQuotaExceededError on HTTP 429', async () => {
  const fakeFetch: typeof fetch = async () => new Response('rate limited', { status: 429 });
  await assertRejects(
    () => identifyFoodItems(new Uint8Array([1]), 'fake-key', fakeFetch),
    GeminiQuotaExceededError,
  );
});

Deno.test('identifyFoodItems throws GeminiUnavailableError on other HTTP errors', async () => {
  const fakeFetch: typeof fetch = async () => new Response('server error', { status: 500 });
  await assertRejects(
    () => identifyFoodItems(new Uint8Array([1]), 'fake-key', fakeFetch),
    GeminiUnavailableError,
  );
});

Deno.test('identifyFoodItems throws GeminiUnavailableError when response has no text content', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(JSON.stringify({ candidates: [] }), { status: 200 });
  await assertRejects(
    () => identifyFoodItems(new Uint8Array([1]), 'fake-key', fakeFetch),
    GeminiUnavailableError,
  );
});
