import type { SofiaAgentConfig } from "../config";
import {
  claimNextSofiaAgentTask,
  countUsersCreatedTodayForSofia,
  countUsersForSofia,
  createSofiaAgentMessage,
  getLatestDraftForTask,
  listRecentOracleQueriesForSofia,
  listSofiaThreadMessages,
  listSofiaAgentTasksByStatus,
  markSofiaAgentTaskApproved,
  markSofiaAgentTaskFailed,
  markSofiaAgentTaskSent,
  saveSofiaAgentDraft,
  setSofiaSearchTargetEnabled,
} from "../db";
import { generateSofiaDraft } from "./openai";
import { buildSofiaPersonaProfile, buildSofiaSystemPrompt } from "./persona";
import { buildSofiaTaskPrompt } from "./prompts";
import { sendTelegramText } from "./mtproto";

function isInboxTask(taskType: string): boolean {
  return taskType === "dm_reply" || taskType === "natal_chart_reply";
}

function isCommunityTask(taskType: string): boolean {
  return taskType === "channel_comment" || taskType === "group_outreach";
}

function isOwnedChannelPostTask(taskType: string): boolean {
  return taskType === "channel_post";
}

function isAdminBotSummaryTask(
  task: { taskType: string; payload: Record<string, unknown> },
  config: SofiaAgentConfig,
): boolean {
  if (!isInboxTask(task.taskType)) {
    return false;
  }
  if (task.payload.adminCommand !== "bot_summary") {
    return false;
  }
  const approverHandle = normalizeHandle(config.outreachReportChat);
  const chatHandle = normalizeHandle(
    typeof task.payload.chatUsername === "string" ? `@${task.payload.chatUsername}` : null,
  );
  return Boolean(approverHandle && chatHandle && approverHandle === chatHandle);
}

function isSocialCommunityTask(task: { taskType: string; payload: Record<string, unknown> }): boolean {
  return isCommunityTask(task.taskType) && task.payload.category === "social";
}

function normalizeHandle(value: string | null | undefined): string | null {
  if (!value) {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.startsWith("@") ? trimmed.toLowerCase() : `@${trimmed.toLowerCase()}`;
}

function isCommunityAccessLossError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return /CHANNEL_PRIVATE|CHAT_ADMIN_REQUIRED|CHAT_FORBIDDEN|CHAT_WRITE_FORBIDDEN|CHANNEL_INVALID|USER_BANNED_IN_CHANNEL|PEER_ID_INVALID/i.test(
    message,
  );
}

function isAllowedTask(taskType: string, config: SofiaAgentConfig): boolean {
  if (isInboxTask(taskType)) {
    return true;
  }
  if (config.communityModeEnabled && isCommunityTask(taskType)) {
    return true;
  }
  if (config.ownedChannelEnabled && isOwnedChannelPostTask(taskType)) {
    return true;
  }
  return false;
}

function buildImmediateCommunityReport(
  task: Awaited<ReturnType<typeof listSofiaAgentTasksByStatus>>[number],
  draftText: string,
): string {
  const where = task.sourceChannel || task.targetChat || task.title;
  const sourceText =
    typeof task.payload.sourceText === "string" ? task.payload.sourceText.trim() : "";
  const sourcePermalink =
    typeof task.payload.sourcePermalink === "string" ? task.payload.sourcePermalink : null;
  const replyToMessageId =
    typeof task.payload.replyToMessageId === "number"
      ? task.payload.replyToMessageId
      : task.payload.replyToMessageId
        ? Number(task.payload.replyToMessageId)
        : null;
  const lines = [
    `Sofia reply sent: ${where}`,
    sourceText ? `Source: ${sourceText}` : "",
    `Reply: ${draftText.replace(/\s+/g, " ").trim()}`,
    sourcePermalink ? `Link: ${sourcePermalink}` : "",
    Number.isFinite(replyToMessageId) ? `ReplyTo: ${replyToMessageId}` : "",
  ].filter(Boolean);
  return lines.join("\n");
}

function buildConversationContext(messages: Awaited<ReturnType<typeof listSofiaThreadMessages>>): string {
  return messages
    .map((message) => {
      const speaker =
        message.direction === "outbound"
          ? "Sofia"
          : (message.senderLabel?.trim() || "User");
      const timestamp = new Date(message.sentAt).toISOString().replace("T", " ").slice(0, 16);
      return `[${timestamp}] ${speaker}: ${message.messageText}`;
    })
    .join("\n");
}

function formatBotQueryType(queryType: string): string {
  if (queryType.startsWith("reading_")) {
    return `Расклад (${queryType.replace("reading_", "")})`;
  }
  if (queryType === "natal_chart") {
    return "Натальная карта";
  }
  if (queryType === "compatibility") {
    return "Совместимость";
  }
  return queryType;
}

async function buildAdminBotSummaryReply(): Promise<string> {
  const [todayCount, totalCount, recentQueries] = await Promise.all([
    countUsersCreatedTodayForSofia(),
    countUsersForSofia(),
    listRecentOracleQueriesForSofia(8),
  ]);

  const lines = [
    "По основному боту сейчас так:",
    `Сегодня добавилось пользователей: ${todayCount}`,
    `Всего пользователей: ${totalCount}`,
  ];

  if (recentQueries.length === 0) {
    lines.push("", "Последних запросов пока не вижу.");
    return lines.join("\n");
  }

  lines.push("", "Последние запросы пользователей:");
  for (const row of recentQueries) {
    const createdAt = row.createdAt
      ? new Date(row.createdAt).toISOString().replace("T", " ").slice(0, 16)
      : "-";
    const question = row.question.replace(/\s+/g, " ").trim();
    const shortQuestion = question.length > 140 ? `${question.slice(0, 137)}...` : question;
    lines.push(
      `- ${createdAt} · user_id=${row.telegramUserId} · ${formatBotQueryType(row.queryType)} · ${row.locale ?? "-"}${shortQuestion ? ` · ${shortQuestion}` : ""}`,
    );
  }
  return lines.join("\n");
}

function buildReplyGuidance(
  task: { taskType: string; payload: Record<string, unknown> },
  taskType: string,
  messages: Awaited<ReturnType<typeof listSofiaThreadMessages>>,
  recommendBotUrl: string,
): string | undefined {
  const now = Date.now();
  const recentWindowMs = 24 * 60 * 60 * 1000;
  const recentOutbound = messages.filter((message) => message.direction === "outbound");
  const recentBotMention = recentOutbound.some(
    (message) =>
      now - message.sentAt <= recentWindowMs &&
      (message.messageText.includes(recommendBotUrl) || message.messageText.includes("@tarot_arkana_bot")),
  );
  const targetHandle =
    normalizeHandle(
      typeof task.payload.effectiveTargetChat === "string"
        ? task.payload.effectiveTargetChat
        : typeof task.payload.requestedTargetChat === "string"
          ? task.payload.requestedTargetChat
          : null,
    ) ?? normalizeHandle((task as { targetChat?: string | null }).targetChat);

  const rules: string[] = [];
  if (isInboxTask(taskType)) {
    if (recentOutbound.length === 0) {
      rules.push(
        `In this first reply, be warm and polite, then explicitly say that you can help with a natal chart reading or a tarot spread, and include the bot link once: ${recommendBotUrl}. Present it as an optional helpful tool, not a pushy CTA.`,
      );
      rules.push(
        "A good first-reply pattern is: short human acknowledgment -> one sentence about what kind of help is available -> bot link -> optional one-line invitation to send details.",
      );
    } else if (!recentBotMention) {
      rules.push(
        `If the user still seems to need direction, you may briefly remind them that you can help with a natal chart reading or tarot spread via ${recommendBotUrl}. Do not force it, and do not mention it more than once per 24 hours in the same thread.`,
      );
    } else {
      rules.push("Do not mention the bot again in this reply unless the user directly asks for a tool or link.");
    }
  }

  if (isCommunityTask(taskType)) {
    rules.push("Comment only if you can add real value to the discussion in 1-4 short Telegram-style lines.");
    rules.push("Do not sound promotional or salesy.");
    rules.push("If you are replying in comments, keep it polite, short, and socially light. A small emoji is fine if it fits naturally.");
    rules.push("Prefer entering the conversation like a real participant: react to the actual point, add one useful thought, and often end with one natural follow-up question.");
    rules.push("Write consistently from Sofia's female point of view. In Russian, use natural feminine self-reference where it matters.");
    if (isSocialCommunityTask(task)) {
      rules.push("Do not mention any bot, product, or service in this reply.");
      rules.push("For relocation and expat chats, keep the tone natural, neighborly, and practical.");
      rules.push("Vary the rhythm and texture of replies. Some should be short and cheerful, some practical, some lightly reflective about life or fate, but most should feel upbeat and easy.");
      rules.push("Avoid repeating the same structure in every message. Sometimes ask a warm follow-up question, sometimes just leave a compact encouraging thought.");
      rules.push("If the original message is casual, your reply can be casual too. Do not over-therapize ordinary chat.");
      if (targetHandle === "@rfaze") {
        rules.push("For @rfaze specifically, keep the tone maximally neutral and context-first.");
        rules.push("Do not force a follow-up question. Many good replies here should end as a simple statement or reaction.");
        rules.push("Keep the message compact and unshowy. A small emoji is fine occasionally, but only if it feels native to the thread.");
        rules.push("Mirror the local chat rhythm: if the thread is dry and practical, be dry and practical; if it is light, be light.");
      }
      if (targetHandle === "@ruskievstambule") {
        rules.push("For @ruskievstambule specifically, keep the tone extra careful, low-key, and grounded.");
        rules.push("Use the nearby chat context before replying. React to what people around the message are actually discussing, not only to the single line itself.");
        rules.push("Dial enthusiasm down. Prefer calm, natural phrasing over bright encouragement.");
        rules.push("Do not make every reply structurally similar. Many good replies here are one compact thought, one practical tip, or one quiet reaction.");
        rules.push("Do not end every reply with a question. Only ask one if the thread naturally opens that door.");
      }
    } else {
      rules.push(
        `Mention ${recommendBotUrl} only if the conversation is explicitly about where to get a personal reading, a tarot spread, or a horoscope tool. If you mention it, do it briefly at the end, frame it as a genuinely useful self-reflection tool rather than an ad, and only once.`,
      );
    }
  }

  if (isOwnedChannelPostTask(taskType)) {
    rules.push("Write in a channel-author voice: distinct, authored, and worth reading.");
    rules.push("Keep it original and avoid generic horoscope filler.");
    rules.push("For @estartarot, write in Russian.");
    rules.push(
      `You may softly mention ${recommendBotUrl} only if it fits the post organically, ideally as an optional tool rather than a CTA-heavy promo.`,
    );
  }

  return rules.length ? rules.map((rule) => `- ${rule}`).join("\n") : undefined;
}

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
    if (!isAllowedTask(task.taskType, config)) {
      await markSofiaAgentTaskFailed(task.id, `Task type ${task.taskType} is disabled in current mode`);
      continue;
    }
    try {
      if (isAdminBotSummaryTask(task, config)) {
        const draftText = await buildAdminBotSummaryReply();
        await saveSofiaAgentDraft({
          taskId: task.id,
          draftText,
          model: "system",
          notes: "admin_bot_summary",
        });
        await markSofiaAgentTaskApproved(task.id);
        processed += 1;
        continue;
      }
      const systemPrompt = buildSofiaSystemPrompt(config.personaDisplayName, config.personaHandle);
      const persona = buildSofiaPersonaProfile(config.personaDisplayName, config.personaHandle);
      const threadId =
        typeof task.payload.threadId === "number"
          ? task.payload.threadId
          : Number(task.payload.threadId);
      const contextMessages = Number.isFinite(threadId)
        ? await listSofiaThreadMessages(threadId, 14)
        : [];
      const prompt = buildSofiaTaskPrompt(
        task,
        contextMessages.length ? buildConversationContext(contextMessages) : undefined,
        buildReplyGuidance(task, task.taskType, contextMessages, config.recommendBotUrl),
      );
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
      if (
        isInboxTask(task.taskType) ||
        isSocialCommunityTask(task) ||
        (config.ownedChannelEnabled && isOwnedChannelPostTask(task.taskType))
      ) {
        await markSofiaAgentTaskApproved(task.id);
      }
      processed += 1;
    } catch (error) {
      const searchTargetId =
        typeof task.payload.searchTargetId === "number"
          ? task.payload.searchTargetId
          : Number(task.payload.searchTargetId);
      if (Number.isFinite(searchTargetId) && isCommunityTask(task.taskType) && isCommunityAccessLossError(error)) {
        await setSofiaSearchTargetEnabled(searchTargetId, false, {
          disabledReason: "access_lost",
          disabledAt: new Date().toISOString(),
          accessError: error instanceof Error ? error.message : String(error),
        });
      }
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
    if (!isAllowedTask(task.taskType, config)) {
      await markSofiaAgentTaskFailed(task.id, `Task type ${task.taskType} is disabled in current mode`);
      continue;
    }
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
      const threadId =
        typeof task.payload.threadId === "number"
          ? task.payload.threadId
          : Number(task.payload.threadId);
      if (Number.isFinite(threadId)) {
        await createSofiaAgentMessage({
          threadId,
          platformMessageId: sent.messageId,
          direction: "outbound",
          senderLabel: config.personaDisplayName,
          messageText: latestDraft.draftText,
          sentAt: Date.now(),
          metadata: {
            taskId: task.id,
            autoSent: true,
          },
        });
      }
      await markSofiaAgentTaskSent(task.id, `telegram_message_id=${sent.messageId}`);
      if (isCommunityTask(task.taskType) && config.outreachReportEnabled && config.outreachReportChat) {
        await sendTelegramText(config, {
          targetChat: config.outreachReportChat,
          message: buildImmediateCommunityReport(task, latestDraft.draftText),
        });
      }
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
