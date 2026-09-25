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
const SEARCH_DATA_TYPES = ['Foundation', 'SR Legacy', 'Survey (FNDDS)'];

// Crude English singularization so "tomato" matches "Tomatoes, raw". Applied to
// both sides, so it only needs to be consistent, not linguistically correct.
function singularize(token: string): string {
  if (token.length <= 3) return token;
  if (token.endsWith('ies')) return `${token.slice(0, -3)}y`;
  if (/(o|ch|sh|x|ss)es$/.test(token)) return token.slice(0, -2);
  if (token.endsWith('s') && !token.endsWith('ss')) return token.slice(0, -1);
  return token;
}

function normalize(text: string): string[] {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((token) => token.length > 0)
    .map(singularize);
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
  // POST because the GET endpoint rejects "Survey (FNDDS)" in the query string.
  // Branded foods are excluded: their label-derived records often lack energy/macros.
  const response = await fetchFn(`https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: foodName, pageSize: 10, dataType: SEARCH_DATA_TYPES }),
  });
  if (!response.ok) {
    console.error(`USDA search failed for "${foodName}": ${response.status} ${await response.text()}`);
    return null;
  }

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
  const nutrients: Array<{ nutrient?: { name?: string; unitName?: string }; amount?: number }> =
    data.foodNutrients ?? [];
  const find = (name: string, preferredUnit?: string) => {
    if (preferredUnit) {
      const preferred = nutrients.find(
        (n) => n.nutrient?.name === name && n.nutrient?.unitName?.toUpperCase() === preferredUnit,
      );
      if (preferred) return preferred.amount ?? 0;
    }
    return nutrients.find((n) => n.nutrient?.name === name)?.amount ?? 0;
  };
  return {
    // Foundation foods report energy only under the Atwater names.
    calories:
      find('Energy', 'KCAL') ||
      find('Energy (Atwater General Factors)', 'KCAL') ||
      find('Energy (Atwater Specific Factors)', 'KCAL'),
    proteinG: find('Protein'),
    carbsG: find('Carbohydrate, by difference'),
    fatG: find('Total lipid (fat)'),
  };
}
