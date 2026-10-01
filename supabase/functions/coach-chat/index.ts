import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders, getUserIdFromAuthHeader, jsonResponse } from '../_shared/http.ts';
import { handleChatRequest } from './handler.ts';
import { createLlmClient } from './llm/factory.ts';
import { SupabaseChatStore, supabaseToolDeps } from './store.ts';

const DEFAULT_DAILY_LIMIT = 30;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !getUserIdFromAuthHeader(req)) {
    return jsonResponse(401, { code: 'UNAUTHORIZED', message: 'Oturum gerekli' });
  }

  try {
    // Kullanıcının JWT'si: tüm okuma/yazmalar RLS'ten geçer (service role yok).
    // COACH_ANON_KEY: projede eski anon key kapalıysa publishable key buraya secret olarak verilir.
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('COACH_ANON_KEY');
    if (!anonKey) throw new Error('SUPABASE_ANON_KEY / COACH_ANON_KEY eksik');
    const client = createClient(Deno.env.get('SUPABASE_URL')!, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const limit = Number.parseInt(Deno.env.get('COACH_DAILY_LIMIT') ?? '', 10);
    const body = await req.json().catch(() => ({}));
    const result = await handleChatRequest(body, {
      store: new SupabaseChatStore(client),
      tools: supabaseToolDeps(client, Deno.env.get('USDA_FDC_API_KEY')!),
      llm: createLlmClient({
        provider: Deno.env.get('LLM_PROVIDER'),
        model: Deno.env.get('LLM_MODEL'),
        geminiApiKey: Deno.env.get('GEMINI_API_KEY'),
      }),
      dailyLimit: Number.isFinite(limit) && limit > 0 ? limit : DEFAULT_DAILY_LIMIT,
      now: () => new Date(),
    });
    return jsonResponse(result.status, result.body);
  } catch (error) {
    console.error(error);
    return jsonResponse(500, { code: 'INTERNAL_ERROR', message: 'Beklenmeyen bir hata oluştu' });
  }
});
