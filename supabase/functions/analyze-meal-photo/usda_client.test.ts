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
          // Shape of the real /food/{fdcId} response (differs from /foods/search).
          { nutrient: { name: 'Energy', unitName: 'kJ' }, amount: 690 },
          { nutrient: { name: 'Energy', unitName: 'kcal' }, amount: 165 },
          { nutrient: { name: 'Protein', unitName: 'g' }, amount: 31 },
          { nutrient: { name: 'Carbohydrate, by difference', unitName: 'g' }, amount: 0 },
          { nutrient: { name: 'Total lipid (fat)', unitName: 'g' }, amount: 3.6 },
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

Deno.test('findBestMatch searches only generic (non-branded) data types', async () => {
  let captured: Request | null = null;
  const fakeFetch: typeof fetch = async (input, init) => {
    captured = new Request(input, init);
    return new Response(JSON.stringify({ foods: [] }), { status: 200 });
  };

  await findBestMatch('tomato', 'fake-key', fakeFetch);
  // Branded records are label-derived and often lack energy/macros entirely.
  const body = await captured!.json();
  assertEquals(captured!.method, 'POST');
  assertEquals(body.query, 'tomato');
  assertEquals(body.dataType, ['Foundation', 'SR Legacy', 'Survey (FNDDS)']);
});

Deno.test('fetchMacrosPer100g falls back to Atwater energy for Foundation foods', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(
      JSON.stringify({
        foodNutrients: [
          // Foundation foods have no plain "Energy" nutrient (e.g. fdcId 1999634, "Tomato, roma").
          { nutrient: { name: 'Energy (Atwater General Factors)', unitName: 'kcal' }, amount: 21.96 },
          { nutrient: { name: 'Energy (Atwater Specific Factors)', unitName: 'kcal' }, amount: 18.95 },
          { nutrient: { name: 'Protein', unitName: 'g' }, amount: 0.7 },
        ],
      }),
      { status: 200 },
    );

  const macros = await fetchMacrosPer100g(1999634, 'fake-key', fakeFetch);
  assertAlmostEquals(macros.calories, 21.96);
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
