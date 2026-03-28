import Anthropic from '@anthropic-ai/sdk';
import { config } from '../../config/env';
import { AIDraftLog } from '../../models/AIDraftLog';
import { logger } from '../../utils/logger';
import {
  LOTO_SYSTEM_PROMPT,
  LOTO_DRAFT_PROMPT,
  TRANSLATION_PROMPT,
  REVIEW_VALIDATION_PROMPT,
} from './prompts';
import type { IAIDraftInput, IAIDraftOutput } from '@soteria/shared';

const MODEL = 'claude-sonnet-4-6';

export class AIService {
  private static client = new Anthropic({ apiKey: config.anthropic.apiKey });

  /**
   * Generate a LOTO procedure draft from field walkdown data.
   * Returns structured JSON output for human review.
   */
  static async generateDraft(
    input: IAIDraftInput,
    userId: string,
    companyId: string,
    placardId?: string
  ): Promise<IAIDraftOutput> {
    const startMs = Date.now();

    const userPrompt = LOTO_DRAFT_PROMPT(input as unknown as Record<string, unknown>);

    let response: Anthropic.Message;
    try {
      response = await AIService.client.messages.create({
        model: MODEL,
        max_tokens: 4096,
        system: LOTO_SYSTEM_PROMPT,
        messages: [{ role: 'user', content: userPrompt }],
      });
    } catch (err) {
      logger.error('[AIService] Claude API error:', err);
      throw new Error('AI service unavailable. Please try again or proceed with manual entry.');
    }

    const rawText = response.content[0].type === 'text' ? response.content[0].text : '';
    const durationMs = Date.now() - startMs;

    let output: IAIDraftOutput;
    try {
      // Claude should return pure JSON — extract it if wrapped in markdown
      const jsonMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)```/) || [null, rawText];
      output = JSON.parse(jsonMatch[1] ?? rawText) as IAIDraftOutput;
    } catch (parseErr) {
      logger.error('[AIService] Failed to parse AI response:', rawText);
      throw new Error('AI returned an unparseable response. Please retry or proceed manually.');
    }

    // Log for audit + billing tracking
    await AIDraftLog.create({
      companyId,
      placardId,
      userId,
      input,
      output,
      modelUsed: MODEL,
      promptTokens: response.usage.input_tokens,
      completionTokens: response.usage.output_tokens,
      durationMs,
    });

    return output;
  }

  /**
   * Translate placard content to Spanish.
   */
  static async translateToSpanish(
    content: Record<string, unknown>,
    userId: string,
    companyId: string
  ): Promise<Record<string, unknown>> {
    const userPrompt = TRANSLATION_PROMPT(content);

    const response = await AIService.client.messages.create({
      model: MODEL,
      max_tokens: 4096,
      system: LOTO_SYSTEM_PROMPT,
      messages: [{ role: 'user', content: userPrompt }],
    });

    const rawText = response.content[0].type === 'text' ? response.content[0].text : '';
    const jsonMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)```/) || [null, rawText];

    try {
      return JSON.parse(jsonMatch[1] ?? rawText) as Record<string, unknown>;
    } catch {
      throw new Error('Translation service returned an unparseable response');
    }
  }

  /**
   * Review a procedure draft for completeness gaps.
   */
  static async reviewDraft(
    placardContent: Record<string, unknown>,
    userId: string,
    companyId: string
  ): Promise<Record<string, unknown>> {
    const userPrompt = REVIEW_VALIDATION_PROMPT(placardContent);

    const response = await AIService.client.messages.create({
      model: MODEL,
      max_tokens: 2048,
      system: LOTO_SYSTEM_PROMPT,
      messages: [{ role: 'user', content: userPrompt }],
    });

    const rawText = response.content[0].type === 'text' ? response.content[0].text : '';
    const jsonMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)```/) || [null, rawText];

    try {
      return JSON.parse(jsonMatch[1] ?? rawText) as Record<string, unknown>;
    } catch {
      throw new Error('Review service returned an unparseable response');
    }
  }
}
