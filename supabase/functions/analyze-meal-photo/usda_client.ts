export interface UsdaFood {
  fdcId: number;
  description: string;
  dataType: string;
}

export interface Macros {
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}

const PREFERRED_DATA_TYPES = new Set(['Foundation', 'SR Legacy']);
const MATCH_THRESHOLD = 0.3;

function normalize(text: string): string[] {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((token) => token.length > 0);
}

export function scoreMatch(query: string, candidate: UsdaFood): number {
  const queryTokens = new Set(normalize(query));
  const candidateTokens = new Set(normalize(candidate.description));
  if (queryTokens.size === 0 || candidateTokens.size === 0) return 0;

  let overlap = 0;
  for (const token of queryTokens) {
    if (candidateTokens.has(token)) overlap += 1;
  }
  const union = new Set([...queryTokens, ...candidateTokens]).size;
  const jaccard = overlap / union;
  const typeBonus = PREFERRED_DATA_TYPES.has(candidate.dataType) ? 0.1 : 0;
  return jaccard + typeBonus;
}

export async function findBestMatch(
  foodName: string,
  apiKey: string,
  fetchFn: typeof fetch = fetch,
): Promise<UsdaFood | null> {
  const url =
    `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${apiKey}` +
    `&query=${encodeURIComponent(foodName)}&pageSize=10`;
  const response = await fetchFn(url);
  if (!response.ok) return null;

  const data = await response.json();
  const foods = (data.foods ?? []) as UsdaFood[];
  if (foods.length === 0) return null;

  let best: UsdaFood | null = null;
  let bestScore = 0;
  for (const food of foods) {
    const score = scoreMatch(foodName, food);
    if (score > bestScore) {
      bestScore = score;
      best = food;
    }
  }
  return bestScore >= MATCH_THRESHOLD ? best : null;
}

export async function fetchMacrosPer100g(
  fdcId: number,
  apiKey: string,
  fetchFn: typeof fetch = fetch,
): Promise<Macros> {
  const url = `https://api.nal.usda.gov/fdc/v1/food/${fdcId}?api_key=${apiKey}`;
  const response = await fetchFn(url);
  if (!response.ok) {
    throw new Error(`USDA food detail request failed: ${response.status}`);
  }
  const data = await response.json();
  const nutrients: Array<{ nutrientName: string; value: number }> = data.foodNutrients ?? [];
  const find = (name: string) => nutrients.find((n) => n.nutrientName === name)?.value ?? 0;
  return {
    calories: find('Energy'),
    proteinG: find('Protein'),
    carbsG: find('Carbohydrate, by difference'),
    fatG: find('Total lipid (fat)'),
  };
}
