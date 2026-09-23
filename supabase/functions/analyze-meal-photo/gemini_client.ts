export interface FoodPrediction {
  name: string;
  estimatedGrams: number;
}

const GEMINI_MODEL = 'gemini-2.5-flash-lite';

export class GeminiUnavailableError extends Error {}
export class GeminiQuotaExceededError extends Error {}

const PROMPT =
  'Bu fotoğraftaki her yiyeceği ve tahmini gram cinsinden porsiyonunu belirle. ' +
  'Sadece JSON döndür, başka açıklama ekleme. ' +
  'Format: {"items": [{"name": string, "estimated_grams": number}]}. ' +
  'Makro veya kalori hesabı yapma, sadece tanıma ve porsiyon tahmini yap.';

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

export async function identifyFoodItems(
  photoBytes: Uint8Array,
  apiKey: string,
  fetchFn: typeof fetch = fetch,
): Promise<FoodPrediction[]> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;
  const body = {
    contents: [
      {
        parts: [
          { text: PROMPT },
          { inline_data: { mime_type: 'image/jpeg', data: bytesToBase64(photoBytes) } },
        ],
      },
    ],
    generationConfig: { responseMimeType: 'application/json' },
  };

  const response = await fetchFn(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (response.status === 429) {
    throw new GeminiQuotaExceededError('Gemini rate limit exceeded');
  }
  if (!response.ok) {
    throw new GeminiUnavailableError(`Gemini request failed: ${response.status}`);
  }

  const data = await response.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== 'string') {
    throw new GeminiUnavailableError('Gemini response missing text content');
  }

  const parsed = JSON.parse(text) as { items: Array<{ name: string; estimated_grams: number }> };
  return parsed.items.map((item) => ({ name: item.name, estimatedGrams: item.estimated_grams }));
}
