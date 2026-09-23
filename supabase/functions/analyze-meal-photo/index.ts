import { GeminiQuotaExceededError, GeminiUnavailableError, identifyFoodItems } from './gemini_client.ts';
import type { FoodPrediction } from './gemini_client.ts';
import { fetchMacrosPer100g, findBestMatch } from './usda_client.ts';
import type { UsdaFood, Macros } from './usda_client.ts';

export interface AnalyzeDeps {
  downloadPhoto: (photoPath: string) => Promise<Uint8Array>;
  identifyFoodItems: (photoBytes: Uint8Array) => Promise<FoodPrediction[]>;
  findBestMatch: (name: string) => Promise<UsdaFood | null>;
  fetchMacrosPer100g: (fdcId: number) => Promise<Macros>;
}

interface ResponseItem {
  name: string;
  grams: number;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  usda_fdc_id: string | null;
  needs_review: boolean;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

export async function handleAnalyzeRequest(
  photoPath: string,
  deps: AnalyzeDeps,
): Promise<{ status: number; body: unknown }> {
  let photoBytes: Uint8Array;
  try {
    photoBytes = await deps.downloadPhoto(photoPath);
  } catch {
    return { status: 404, body: { code: 'PHOTO_NOT_FOUND', message: 'Fotoğraf bulunamadı' } };
  }

  let predictions: FoodPrediction[];
  try {
    predictions = await deps.identifyFoodItems(photoBytes);
  } catch (error) {
    if (error instanceof GeminiQuotaExceededError) {
      return {
        status: 429,
        body: { code: 'GEMINI_QUOTA_EXCEEDED', message: 'Günlük AI analiz limiti doldu' },
      };
    }
    if (error instanceof GeminiUnavailableError) {
      return { status: 503, body: { code: 'GEMINI_UNAVAILABLE', message: 'AI şu an kullanılamıyor' } };
    }
    throw error;
  }

  const items: ResponseItem[] = [];
  for (const prediction of predictions) {
    const match = await deps.findBestMatch(prediction.name);
    if (match === null) {
      items.push({
        name: prediction.name,
        grams: prediction.estimatedGrams,
        calories: 0,
        protein_g: 0,
        carbs_g: 0,
        fat_g: 0,
        usda_fdc_id: null,
        needs_review: true,
      });
      continue;
    }
    const per100g = await deps.fetchMacrosPer100g(match.fdcId);
    const factor = prediction.estimatedGrams / 100;
    items.push({
      name: prediction.name,
      grams: prediction.estimatedGrams,
      calories: round1(per100g.calories * factor),
      protein_g: round1(per100g.proteinG * factor),
      carbs_g: round1(per100g.carbsG * factor),
      fat_g: round1(per100g.fatG * factor),
      usda_fdc_id: String(match.fdcId),
      needs_review: false,
    });
  }

  return { status: 200, body: { items } };
}

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY')!;
  const usdaApiKey = Deno.env.get('USDA_FDC_API_KEY')!;

  try {
    const { photo_path } = await req.json();
    if (!photo_path || typeof photo_path !== 'string') {
      return new Response(
        JSON.stringify({ code: 'PHOTO_NOT_FOUND', message: 'photo_path eksik' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const deps: AnalyzeDeps = {
      downloadPhoto: async (path) => {
        const response = await fetch(`${supabaseUrl}/storage/v1/object/meal-photos/${path}`, {
          headers: { Authorization: `Bearer ${serviceRoleKey}` },
        });
        if (!response.ok) throw new Error(`Storage download failed: ${response.status}`);
        return new Uint8Array(await response.arrayBuffer());
      },
      identifyFoodItems: (bytes) => identifyFoodItems(bytes, geminiApiKey),
      findBestMatch: (name) => findBestMatch(name, usdaApiKey),
      fetchMacrosPer100g: (fdcId) => fetchMacrosPer100g(fdcId, usdaApiKey),
    };

    const result = await handleAnalyzeRequest(photo_path, deps);
    return new Response(JSON.stringify(result.body), {
      status: result.status,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error(error);
    return new Response(
      JSON.stringify({ code: 'INTERNAL_ERROR', message: 'Beklenmeyen bir hata oluştu' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
