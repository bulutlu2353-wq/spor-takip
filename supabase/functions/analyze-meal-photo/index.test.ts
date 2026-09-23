import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { GeminiQuotaExceededError, GeminiUnavailableError } from './gemini_client.ts';
import { handleAnalyzeRequest } from './index.ts';
import type { AnalyzeDeps } from './index.ts';

function baseDeps(overrides: Partial<AnalyzeDeps> = {}): AnalyzeDeps {
  return {
    downloadPhoto: async () => new Uint8Array([1, 2, 3]),
    identifyFoodItems: async () => [
      { name: 'Tavuk', estimatedGrams: 150, usdaQuery: 'grilled chicken' },
    ],
    findBestMatch: async () => ({ fdcId: 171077, description: 'Chicken breast', dataType: 'Foundation' }),
    fetchMacrosPer100g: async () => ({ calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6 }),
    ...overrides,
  };
}

Deno.test('returns matched items with macros scaled by grams', async () => {
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', baseDeps());
  assertEquals(result.status, 200);
  const body = result.body as { items: Array<Record<string, unknown>> };
  assertEquals(body.items.length, 1);
  assertEquals(body.items[0].name, 'Tavuk');
  assertEquals(body.items[0].grams, 150);
  assertEquals(body.items[0].calories, 247.5);
  assertEquals(body.items[0].needs_review, false);
  assertEquals(body.items[0].usda_fdc_id, '171077');
});

Deno.test('marks an item needs_review when USDA has no match', async () => {
  const deps = baseDeps({ findBestMatch: async () => null });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  const body = result.body as { items: Array<Record<string, unknown>> };
  assertEquals(body.items[0].needs_review, true);
  assertEquals(body.items[0].calories, 0);
  assertEquals(body.items[0].usda_fdc_id, null);
});

Deno.test('returns GEMINI_QUOTA_EXCEEDED with 429 when Gemini rate-limits', async () => {
  const deps = baseDeps({
    identifyFoodItems: async () => {
      throw new GeminiQuotaExceededError('rate limited');
    },
  });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  assertEquals(result.status, 429);
  assertEquals((result.body as { code: string }).code, 'GEMINI_QUOTA_EXCEEDED');
});

Deno.test('returns GEMINI_UNAVAILABLE with 503 when Gemini fails', async () => {
  const deps = baseDeps({
    identifyFoodItems: async () => {
      throw new GeminiUnavailableError('down');
    },
  });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  assertEquals(result.status, 503);
  assertEquals((result.body as { code: string }).code, 'GEMINI_UNAVAILABLE');
});

Deno.test('returns PHOTO_NOT_FOUND with 404 when the photo cannot be downloaded', async () => {
  const deps = baseDeps({
    downloadPhoto: async () => {
      throw new Error('404 from storage');
    },
  });
  const result = await handleAnalyzeRequest('missing.jpg', deps);
  assertEquals(result.status, 404);
  assertEquals((result.body as { code: string }).code, 'PHOTO_NOT_FOUND');
});

Deno.test('handles multiple predicted items independently', async () => {
  const deps = baseDeps({
    identifyFoodItems: async () => [
      { name: 'Tavuk', estimatedGrams: 150, usdaQuery: 'grilled chicken' },
      { name: 'Bilinmeyen sos', estimatedGrams: 30, usdaQuery: 'unknown sauce' },
    ],
    findBestMatch: async (query: string) =>
      query === 'grilled chicken'
        ? { fdcId: 171077, description: 'Chicken breast', dataType: 'Foundation' }
        : null,
  });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  const body = result.body as { items: Array<Record<string, unknown>> };
  assertEquals(body.items.length, 2);
  assertEquals(body.items[0].needs_review, false);
  assertEquals(body.items[1].needs_review, true);
});

Deno.test('calls findBestMatch with usdaQuery, not the Turkish display name', async () => {
  let receivedQuery: string | undefined;
  const deps = baseDeps({
    identifyFoodItems: async () => [
      { name: 'Izgara tavuk göğsü', estimatedGrams: 150, usdaQuery: 'grilled chicken breast' },
    ],
    findBestMatch: async (query: string) => {
      receivedQuery = query;
      return { fdcId: 171077, description: 'Chicken breast', dataType: 'Foundation' };
    },
  });
  await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  assertEquals(receivedQuery, 'grilled chicken breast');
});
