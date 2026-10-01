import { buildContextText, historyToLlmMessages, localDate } from './context.ts';
import { LlmQuotaError, LlmUnavailableError } from './llm/types.ts';
import type { LlmClient, LlmMessage } from './llm/types.ts';
import { fallbackReply, systemPrompt } from './prompts.ts';
import { prepareToolCall, TOOL_DEFINITIONS } from './tools.ts';
import type { ToolDeps } from './tools.ts';
import type { ContextData, Locale, NewEvent, StoredMessage, ToolName } from './types.ts';

export const HISTORY_LIMIT = 20;
export const MAX_LLM_CALLS = 3;
export const MAX_MESSAGE_LENGTH = 2000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_OFFSET_MINUTES = 14 * 60;

export interface ChatStore {
  countUsageSince(since: Date): Promise<number>;
  recentMessages(limit: number): Promise<StoredMessage[]>;
  loadContext(range: { today: string; dayStart: Date; dayEnd: Date }): Promise<ContextData>;
  targetSnapshot(tool: ToolName, payload: Record<string, unknown>): Promise<unknown>;
  saveExchange(userText: string, assistantText: string, event: NewEvent | null): Promise<StoredMessage[]>;
}

export interface HandlerDeps {
  store: ChatStore;
  tools: ToolDeps;
  llm: LlmClient;
  dailyLimit: number;
  now: () => Date;
}

export interface HandlerResult {
  status: number;
  body: unknown;
}

function failure(status: number, code: string, message: string): HandlerResult {
  return { status, body: { code, message } };
}

export async function handleChatRequest(raw: unknown, deps: HandlerDeps): Promise<HandlerResult> {
  const body = (typeof raw === 'object' && raw !== null ? raw : {}) as Record<string, unknown>;
  const now = deps.now();
  const used = await deps.store.countUsageSince(new Date(now.getTime() - DAY_MS));
  const remaining = Math.max(0, deps.dailyLimit - used);
  if (body.action === 'status') return { status: 200, body: { remaining } };

  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (message.length === 0 || message.length > MAX_MESSAGE_LENGTH) {
    return failure(400, 'INVALID_MESSAGE', 'Mesaj 1-2000 karakter olmalı');
  }
  if (remaining === 0) {
    return { status: 429, body: { code: 'DAILY_LIMIT', message: 'Günlük mesaj hakkı doldu', remaining: 0 } };
  }
  const locale: Locale = body.locale === 'en' ? 'en' : 'tr';
  const offset = typeof body.utc_offset_minutes === 'number' && Math.abs(body.utc_offset_minutes) <= MAX_OFFSET_MINUTES
    ? Math.round(body.utc_offset_minutes)
    : 0;

  const today = localDate(now, offset);
  const dayStart = new Date(Date.parse(`${today}T00:00:00Z`) - offset * 60_000);
  const dayEnd = new Date(dayStart.getTime() + DAY_MS);
  const [history, data] = await Promise.all([
    deps.store.recentMessages(HISTORY_LIMIT),
    deps.store.loadContext({ today, dayStart, dayEnd }),
  ]);

  const system = systemPrompt(locale, buildContextText(data, offset));
  const messages: LlmMessage[] = [...historyToLlmMessages(history), { role: 'user', text: message }];
  const toolContext = { data, now, utcOffsetMinutes: offset, locale };

  let reply = '';
  let event: NewEvent | null = null;
  try {
    for (let call = 0; call < MAX_LLM_CALLS; call++) {
      const response = await deps.llm.generate({ system, messages, tools: TOOL_DEFINITIONS });
      if (response.type === 'text') {
        reply = response.text;
        break;
      }
      const prepared = await prepareToolCall(response.name, response.args, toolContext, deps.tools);
      if (prepared.ok) {
        const base = await deps.store.targetSnapshot(prepared.tool, prepared.payload);
        event = { tool: prepared.tool, summary: prepared.summary, payload: prepared.payload, base };
        reply = response.text || prepared.summary;
        break;
      }
      console.warn(`Tool call rejected (${response.name}): ${prepared.error}`);
      messages.push({ role: 'assistant_tool_call', name: response.name, args: response.args, raw: response.raw });
      messages.push({
        role: 'tool_result',
        name: response.name,
        result: { error: prepared.error, candidates: prepared.candidates ?? [] },
      });
    }
  } catch (error) {
    if (error instanceof LlmQuotaError) {
      console.error(error);
      return failure(429, 'LLM_QUOTA', 'Antrenör şu an çok yoğun');
    }
    if (error instanceof LlmUnavailableError) {
      console.error(error);
      return failure(503, 'LLM_UNAVAILABLE', 'Antrenöre şu an ulaşılamıyor');
    }
    throw error;
  }

  if (!reply) reply = fallbackReply(locale);
  const saved = await deps.store.saveExchange(message, reply, event);
  return { status: 200, body: { messages: saved, remaining: remaining - 1 } };
}
