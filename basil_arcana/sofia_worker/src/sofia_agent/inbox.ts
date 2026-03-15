import type { SofiaAgentConfig } from "../config";
import {
  createSofiaAgentMessage,
  createSofiaAgentTask,
  findSofiaTaskByDedupKey,
  upsertSofiaAgentThread,
} from "../db";
import { fetchRecentPrivateMessages } from "./mtproto";

function inferDmTaskType(text: string): "dm_reply" | "natal_chart_reply" {
  const normalized = text.toLowerCase();
  if (
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
      },
    });

    if (!saved.inserted || message.outgoing) {
      continue;
    }

    newMessages += 1;
    const dedupKey = `dm:${thread.externalThreadId}:${message.id}`;
    const existingTask = await findSofiaTaskByDedupKey(dedupKey);
    if (existingTask) {
      continue;
    }

    const taskType = inferDmTaskType(message.text);
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
      },
    });
    tasksCreated += 1;
  }

  return { threadsUpserted, newMessages, tasksCreated };
}
