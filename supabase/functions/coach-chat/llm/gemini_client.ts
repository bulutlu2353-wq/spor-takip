import { LlmQuotaError, LlmUnavailableError } from './types.ts';
import type { LlmClient, LlmMessage, LlmRequest, LlmResponse } from './types.ts';

const TIMEOUT_MS = 25_000;

interface GeminiPart {
  text?: string;
  thought?: boolean;
  functionCall?: { name: string; args?: Record<string, unknown> };
  functionResponse?: { name: string; response: Record<string, unknown> };
  thoughtSignature?: string;
}

function toContents(messages: LlmMessage[]): Array<{ role: string; parts: GeminiPart[] }> {
  return messages.map((message) => {
    switch (message.role) {
      case 'user':
        return { role: 'user', parts: [{ text: message.text }] };
      case 'assistant':
        return { role: 'model', parts: [{ text: message.text }] };
      case 'assistant_tool_call':
        // Gemini 3, function calling turlarında thoughtSignature'ın geri gönderilmesini
        // ister: modelin döndürdüğü parça aynen gönderilir.
        return {
          role: 'model',
          parts: [(message.raw as GeminiPart | undefined) ?? { functionCall: { name: message.name, args: message.args } }],
        };
      case 'tool_result':
        return { role: 'user', parts: [{ functionResponse: { name: message.name, response: message.result } }] };
    }
  });
}

export class GeminiClient implements LlmClient {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async generate(req: LlmRequest): Promise<LlmResponse> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;
    const body: Record<string, unknown> = {
      systemInstruction: { parts: [{ text: req.system }] },
      contents: toContents(req.messages),
    };
    if (req.tools.length > 0) {
      body.tools = [{ functionDeclarations: req.tools }];
    }

    let response: Response;
    try {
      response = await this.fetchFn(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch (error) {
      throw new LlmUnavailableError(`Gemini request failed: ${error}`);
    }
    if (response.status === 429) {
      throw new LlmQuotaError('Gemini rate limit exceeded');
    }
    if (!response.ok) {
      throw new LlmUnavailableError(`Gemini request failed: ${response.status} ${await response.text()}`);
    }

    const data = await response.json();
    const parts: GeminiPart[] = data?.candidates?.[0]?.content?.parts ?? [];
    const text = parts
      .filter((part) => typeof part.text === 'string' && !part.thought)
      .map((part) => part.text)
      .join('')
      .trim();
    const call = parts.find((part) => part.functionCall);
    if (call?.functionCall) {
      return { type: 'tool_call', name: call.functionCall.name, args: call.functionCall.args ?? {}, text, raw: call };
    }
    if (text.length === 0) {
      throw new LlmUnavailableError(`Gemini returned no content: ${JSON.stringify(data)}`);
    }
    return { type: 'text', text };
  }
}
