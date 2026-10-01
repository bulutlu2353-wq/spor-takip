// Sağlayıcıdan bağımsız LLM formatı. Sağlayıcıya özgü çeviri yalnız *_client.ts
// dosyalarındadır; yeni sağlayıcı = yeni bir client + factory.ts'te bir satır.

export type LlmMessage =
  | { role: 'user'; text: string }
  | { role: 'assistant'; text: string }
  | { role: 'assistant_tool_call'; name: string; args: Record<string, unknown>; raw?: unknown }
  | { role: 'tool_result'; name: string; result: Record<string, unknown> };
export interface ToolDefinition { name: string; description: string; parameters: Record<string, unknown> }
export interface LlmRequest { system: string; messages: LlmMessage[]; tools: ToolDefinition[] }
export type LlmResponse =
  | { type: 'text'; text: string }
  | { type: 'tool_call'; name: string; args: Record<string, unknown>; text: string; raw?: unknown };
export interface LlmClient { generate(req: LlmRequest): Promise<LlmResponse> }
export class LlmQuotaError extends Error {}
export class LlmUnavailableError extends Error {}
