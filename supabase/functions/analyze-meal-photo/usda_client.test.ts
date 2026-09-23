import { assertEquals, assertAlmostEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { fetchMacrosPer100g, findBestMatch, scoreMatch } from './usda_client.ts';
import type { UsdaFood } from './usda_client.ts';

Deno.test('scoreMatch gives a high score for near-identical descriptions', () => {
  const candidate: UsdaFood = { fdcId: 1, description: 'Chicken breast, grilled', dataType: 'Foundation' };
  const score = scoreMatch('grilled chicken breast', candidate);
  assertEquals(score > 0.5, true);
});

Deno.test('scoreMatch gives a low score for unrelated descriptions', () => {
  const candidate: UsdaFood = { fdcId: 2, description: 'Chocolate cake', dataType: 'SR Legacy' };
  const score = scoreMatch('grilled chicken breast', candidate);
  assertEquals(score < 0.2, true);
});

Deno.test('findBestMatch returns the highest-scoring food above the threshold', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(
      JSON.stringify({
        foods: [
          { fdcId: 1, description: 'Chocolate cake', dataType: 'SR Legacy' },
          { fdcId: 2, description: 'Chicken breast, grilled', dataType: 'Foundation' },
        ],
      }),
      { status: 200 },
    );

  const match = await findBestMatch('grilled chicken breast', 'fake-key', fakeFetch);
  assertEquals(match?.fdcId, 2);
});

Deno.test('findBestMatch returns null when no candidate clears the threshold', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(JSON.stringify({ foods: [{ fdcId: 3, description: 'Chocolate cake', dataType: 'SR Legacy' }] }), {
      status: 200,
    });

  const match = await findBestMatch('grilled chicken breast', 'fake-key', fakeFetch);
  assertEquals(match, null);
});

Deno.test('findBestMatch returns null when the search request fails', async () => {
  const fakeFetch: typeof fetch = async () => new Response('error', { status: 500 });
  const match = await findBestMatch('anything', 'fake-key', fakeFetch);
  assertEquals(match, null);
});

Deno.test('fetchMacrosPer100g extracts the four tracked nutrients', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(
      JSON.stringify({
        foodNutrients: [
          { nutrientName: 'Energy', value: 165 },
          { nutrientName: 'Protein', value: 31 },
          { nutrientName: 'Carbohydrate, by difference', value: 0 },
          { nutrientName: 'Total lipid (fat)', value: 3.6 },
        ],
      }),
      { status: 200 },
    );

  const macros = await fetchMacrosPer100g(2, 'fake-key', fakeFetch);
  assertAlmostEquals(macros.calories, 165);
  assertAlmostEquals(macros.proteinG, 31);
  assertAlmostEquals(macros.carbsG, 0);
  assertAlmostEquals(macros.fatG, 3.6);
});

Deno.test('fetchMacrosPer100g throws when the detail request fails', async () => {
  const fakeFetch: typeof fetch = async () => new Response('error', { status: 404 });
  let threw = false;
  try {
    await fetchMacrosPer100g(999, 'fake-key', fakeFetch);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
