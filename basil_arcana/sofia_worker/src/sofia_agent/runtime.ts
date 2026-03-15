import type { SofiaAgentConfig } from "../config";
import {
  claimNextSofiaAgentTask,
  getLatestDraftForTask,
  listSofiaAgentTasksByStatus,
  markSofiaAgentTaskFailed,
  markSofiaAgentTaskSent,
  saveSofiaAgentDraft,
} from "../db";
import { generateSofiaDraft } from "./openai";
import { buildSofiaPersonaProfile, buildSofiaSystemPrompt } from "./persona";
import { buildSofiaTaskPrompt } from "./prompts";
import { sendTelegramText } from "./mtproto";

export async function runSofiaGenerationBatch(
  config: SofiaAgentConfig,
  limit = config.generationBatchSize,
): Promise<number> {
  if (!config.openAiApiKey) {
    throw new Error("OPENAI_API_KEY is required for Sofia generation");
  }
  const batchSize = Math.max(1, Math.min(20, limit));
  let processed = 0;
  for (let index = 0; index < batchSize; index += 1) {
    const task = await claimNextSofiaAgentTask();
    if (!task) {
      break;
    }
    try {
      const systemPrompt = buildSofiaSystemPrompt(config.personaDisplayName, config.personaHandle);
      const persona = buildSofiaPersonaProfile(config.personaDisplayName, config.personaHandle);
      const prompt = buildSofiaTaskPrompt(task);
      const result = await generateSofiaDraft({
        apiKey: config.openAiApiKey,
        model: config.openAiModel,
        systemPrompt,
        taskPrompt: prompt,
      });
      const notes = [
        `persona=${persona.displayName}`,
        result.shortRationale ? `rationale=${result.shortRationale}` : "",
        result.riskFlags.length ? `risk_flags=${result.riskFlags.join("|")}` : "",
      ]
        .filter(Boolean)
        .join("\n");
      await saveSofiaAgentDraft({
        taskId: task.id,
        draftText: result.draftText,
        model: config.openAiModel,
        notes,
      });
      processed += 1;
    } catch (error) {
      await markSofiaAgentTaskFailed(
        task.id,
        error instanceof Error ? error.message : String(error),
      );
    }
  }
  return processed;
}

export async function sendApprovedSofiaTasks(config: SofiaAgentConfig, limit = 10): Promise<number> {
  const tasks = await listSofiaAgentTasksByStatus("approved", limit);
  let sentCount = 0;
  for (const task of tasks) {
    if (!task.targetChat) {
      await markSofiaAgentTaskFailed(task.id, "Approved task is missing targetChat");
      continue;
    }
    const latestDraft = await getLatestDraftForTask(task.id);
    if (!latestDraft) {
      await markSofiaAgentTaskFailed(task.id, "Approved task has no draft");
      continue;
    }
    try {
      const replyToMessageId =
        typeof task.payload.replyToMessageId === "number"
          ? task.payload.replyToMessageId
          : task.payload.replyToMessageId
            ? Number(task.payload.replyToMessageId)
            : null;
      const sent = await sendTelegramText(config, {
        targetChat: task.targetChat,
        message: latestDraft.draftText,
        replyToMessageId: Number.isFinite(replyToMessageId) ? replyToMessageId : null,
      });
      await markSofiaAgentTaskSent(task.id, `telegram_message_id=${sent.messageId}`);
      sentCount += 1;
    } catch (error) {
      await markSofiaAgentTaskFailed(
        task.id,
        error instanceof Error ? error.message : String(error),
      );
    }
  }
  return sentCount;
}
