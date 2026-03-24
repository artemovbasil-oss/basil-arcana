import type { SofiaAgentConfig } from "../config";
import {
  createSofiaAgentMessage,
  createSofiaAgentTask,
  findSofiaTaskByDedupKey,
  upsertSofiaAgentThread,
} from "../db";
import { fetchRecentPrivateMessages } from "./mtproto";

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

function isApprovalCommand(text: string): boolean {
  const normalized = text.trim().toLowerCase();
  if (!normalized) {
    return false;
  }
  return (
    normalized.startsWith("ok") ||
    normalized.startsWith("approve") ||
    normalized === "all" ||
    normalized === "все" ||
    normalized === "cancel" ||
    normalized.includes("ищи другие") ||
    normalized === "reject"
  );
}

function inferAdminCommand(text: string): "bot_summary" | null {
  const normalized = text.trim().toLowerCase();
  if (!normalized) {
    return null;
  }
  if (
    normalized === "/users_today" ||
    normalized === "/users_all" ||
    normalized === "/oracle_queries"
  ) {
    return "bot_summary";
  }
  if (
    /бот|bot|пользоват|users|user|запрос|queries|query|сегодня|today|всего|total|последн/i.test(normalized)
  ) {
    return "bot_summary";
  }
  return null;
}

function inferDmTaskType(text: string, mediaKind: "photo" | "document" | "other" | null): "dm_reply" | "natal_chart_reply" {
  const normalized = text.toLowerCase();
  if (
    mediaKind === "photo" ||
    normalized.includes("natal") ||
    normalized.includes("birth chart") ||
    normalized.includes("натал") ||
    normalized.includes("карта рождения")
  ) {
    return "natal_chart_reply";
  }
  return "dm_reply";
}

export async function ingestSofiaInbox(config: SofiaAgentConfig): Promise<{
  threadsUpserted: number;
  newMessages: number;
  tasksCreated: number;
}> {
  const sinceMs = Date.now() - config.inboxLookbackHours * 60 * 60 * 1000;
  const recentMessages = await fetchRecentPrivateMessages(
    config,
    config.inboxDialogLimit,
    config.inboxMessageLimit,
  );

  let threadsUpserted = 0;
  let newMessages = 0;
  let tasksCreated = 0;

  for (const message of recentMessages) {
    if (message.sentAt < sinceMs) {
      continue;
    }
    const thread = await upsertSofiaAgentThread({
      externalThreadId: message.peerKey,
      userLabel: message.senderLabel ?? message.chatTitle ?? "Telegram user",
      topic: "direct_messages",
      lastInboundText: message.outgoing ? undefined : message.text,
      metadata: {
        chatId: message.chatId,
        chatTitle: message.chatTitle,
        chatUsername: message.chatUsername,
        latestPermalink: message.permalink,
        mediaKind: message.mediaKind,
      },
    });
    threadsUpserted += 1;

    const saved = await createSofiaAgentMessage({
      threadId: thread.id,
      platformMessageId: message.id,
      direction: message.outgoing ? "outbound" : "inbound",
      senderLabel: message.senderLabel,
      messageText: message.text,
      sentAt: message.sentAt,
      metadata: {
        chatId: message.chatId,
        chatTitle: message.chatTitle,
        chatUsername: message.chatUsername,
        permalink: message.permalink,
        mediaKind: message.mediaKind,
      },
    });

    if (!saved.inserted || message.outgoing) {
      continue;
    }

    const approverHandle = normalizeHandle(config.outreachReportChat);
    const chatHandle = normalizeHandle(message.chatUsername ? `@${message.chatUsername}` : null);
    if (approverHandle && chatHandle === approverHandle && isApprovalCommand(message.text)) {
      continue;
    }
    const adminCommand =
      approverHandle && chatHandle === approverHandle
        ? inferAdminCommand(message.text)
        : null;

    newMessages += 1;
    const dedupKey = `dm:${thread.externalThreadId}:${message.id}`;
    const existingTask = await findSofiaTaskByDedupKey(dedupKey);
    if (existingTask) {
      continue;
    }

    const taskType = inferDmTaskType(message.text, message.mediaKind);
    const titlePrefix = taskType === "natal_chart_reply" ? "Natal chart reply" : "DM reply";
    await createSofiaAgentTask({
      taskType,
      title: `${titlePrefix}: ${message.senderLabel ?? message.chatTitle ?? "Telegram user"}`,
      sourceChannel: null,
      targetChat: message.chatUsername ? `@${message.chatUsername}` : message.chatId,
      payload: {
        dedupKey,
        threadId: thread.id,
        inboundMessageId: message.id,
        chatId: message.chatId,
        sourceText: message.text,
        senderLabel: message.senderLabel,
        chatTitle: message.chatTitle,
        chatUsername: message.chatUsername,
        permalink: message.permalink,
        mediaKind: message.mediaKind,
        adminCommand,
      },
    });
    tasksCreated += 1;
  }

  return { threadsUpserted, newMessages, tasksCreated };
}
