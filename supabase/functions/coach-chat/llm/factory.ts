import { GeminiClient } from './gemini_client.ts';
import type { LlmClient } from './types.ts';

export const DEFAULT_GEMINI_MODEL = 'gemini-3.5-flash-lite';

export interface LlmEnv {
  provider?: string;
  model?: string;
  geminiApiKey?: string;
}

/** LLM_PROVIDER / LLM_MODEL secret'larına göre istemci. Boş değer = varsayılan. */
export function createLlmClient(env: LlmEnv, fetchFn: typeof fetch = fetch): LlmClient {
  const provider = env.provider || 'gemini';
  switch (provider) {
    case 'gemini':
      if (!env.geminiApiKey) throw new Error('GEMINI_API_KEY eksik');
      return new GeminiClient(env.geminiApiKey, env.model || DEFAULT_GEMINI_MODEL, fetchFn);
    default:
      throw new Error(`Bilinmeyen LLM_PROVIDER: ${provider}`);
  }
}
