import { Api, TelegramClient } from "telegram";
import { StringSession } from "telegram/sessions";

import type { SofiaAgentConfig } from "../config";

export interface SofiaMtprotoSelf {
  id: string;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
}

export interface SofiaTelegramDialogSummary {
  peerKey: string;
  title: string;
  username: string | null;
  entityType: "user" | "group" | "channel" | "unknown";
}

export interface SofiaTelegramMessageSummary {
  id: string;
  peerKey: string;
  chatId: string | null;
  chatTitle: string | null;
  chatUsername: string | null;
  senderLabel: string | null;
  text: string;
  outgoing: boolean;
  sentAt: number;
  permalink: string | null;
}

function requireMtprotoConfig(config: SofiaAgentConfig): {
  apiId: number;
  apiHash: string;
  sessionString: string;
} {
  if (!config.telegramApiId || !config.telegramApiHash || !config.telegramSessionString) {
    throw new Error(
      "MTProto is not configured. Set TELEGRAM_API_ID, TELEGRAM_API_HASH, and SOFIA_SESSION_STRING.",
    );
  }
  return {
    apiId: config.telegramApiId,
    apiHash: config.telegramApiHash,
    sessionString: config.telegramSessionString,
  };
}

function titleFromEntity(entity: unknown): string {
  if (!entity || typeof entity !== "object") {
    return "Unknown";
  }
  const record = entity as Record<string, unknown>;
  const title = record.title;
  if (typeof title === "string" && title.trim()) {
    return title.trim();
  }
  const firstName = typeof record.firstName === "string" ? record.firstName.trim() : "";
  const lastName = typeof record.lastName === "string" ? record.lastName.trim() : "";
  const fullName = [firstName, lastName].filter(Boolean).join(" ").trim();
  if (fullName) {
    return fullName;
  }
  const username = typeof record.username === "string" ? record.username.trim() : "";
  return username || "Unknown";
}

function usernameFromEntity(entity: unknown): string | null {
  if (!entity || typeof entity !== "object") {
    return null;
  }
  const value = (entity as Record<string, unknown>).username;
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function entityTypeFromDialog(dialog: unknown): SofiaTelegramDialogSummary["entityType"] {
  if (!dialog || typeof dialog !== "object") {
    return "unknown";
  }
  const record = dialog as Record<string, unknown>;
  if (record.isUser === true) {
    return "user";
  }
  if (record.isGroup === true) {
    return "group";
  }
  if (record.isChannel === true) {
    return "channel";
  }
  return "unknown";
}

function buildPeerKey(entity: unknown, fallback: string): string {
  if (!entity || typeof entity !== "object") {
    return fallback;
  }
  const record = entity as Record<string, unknown>;
  const className = typeof record.className === "string" ? record.className : "peer";
  const id = record.id;
  const idValue = typeof id === "bigint" ? id.toString() : String(id ?? fallback);
  return `${className}:${idValue}`;
}

function entityNumericId(entity: unknown): string | null {
  if (!entity || typeof entity !== "object") {
    return null;
  }
  const id = (entity as Record<string, unknown>).id;
  if (typeof id === "bigint") {
    return id.toString();
  }
  if (typeof id === "number" && Number.isFinite(id)) {
    return String(id);
  }
  if (typeof id === "string" && id.trim()) {
    return id.trim();
  }
  return null;
}

function buildPermalink(username: string | null, messageId: string): string | null {
  if (!username) {
    return null;
  }
  return `https://t.me/${username}/${messageId}`;
}

export async function withSofiaTelegramClient<T>(
  config: SofiaAgentConfig,
  fn: (client: TelegramClient) => Promise<T>,
): Promise<T> {
  const { apiId, apiHash, sessionString } = requireMtprotoConfig(config);
  const client = new TelegramClient(new StringSession(sessionString), apiId, apiHash, {
    connectionRetries: 5,
  });
  await client.connect();
  const authorized = await client.checkAuthorization();
  if (!authorized) {
    await client.disconnect();
    throw new Error("SOFIA_SESSION_STRING is present but not authorized. Refresh the Telegram user session.");
  }
  try {
    return await fn(client);
  } finally {
    await client.disconnect();
  }
}

export async function getSofiaSelf(config: SofiaAgentConfig): Promise<SofiaMtprotoSelf> {
  return withSofiaTelegramClient(config, async (client) => {
    const me = await client.getMe();
    return {
      id: String(me.id),
      username: me.username ?? null,
      firstName: me.firstName ?? null,
      lastName: me.lastName ?? null,
    };
  });
}

export async function listPrivateDialogs(
  config: SofiaAgentConfig,
  limit: number,
): Promise<SofiaTelegramDialogSummary[]> {
  return withSofiaTelegramClient(config, async (client) => {
    const results: SofiaTelegramDialogSummary[] = [];
    for await (const dialog of client.iterDialogs({ limit })) {
      if (!(dialog as unknown as Record<string, unknown>).isUser) {
        continue;
      }
      const entity = (dialog as unknown as Record<string, unknown>).entity;
      results.push({
        peerKey: buildPeerKey(entity, String((dialog as unknown as Record<string, unknown>).id ?? "dialog")),
        title: titleFromEntity(entity),
        username: usernameFromEntity(entity),
        entityType: "user",
      });
    }
    return results;
  });
}

export async function fetchRecentPrivateMessages(
  config: SofiaAgentConfig,
  limitDialogs: number,
  messagesPerDialog: number,
): Promise<SofiaTelegramMessageSummary[]> {
  return withSofiaTelegramClient(config, async (client) => {
    const summaries: SofiaTelegramMessageSummary[] = [];
    for await (const dialog of client.iterDialogs({ limit: limitDialogs })) {
      if (!(dialog as unknown as Record<string, unknown>).isUser) {
        continue;
      }
      const entity = (dialog as unknown as Record<string, unknown>).entity;
      const username = usernameFromEntity(entity);
      const peerKey = buildPeerKey(entity, String((dialog as unknown as Record<string, unknown>).id ?? "dialog"));
      const chatId = entityNumericId(entity);
      const chatTitle = titleFromEntity(entity);
      let count = 0;
      for await (const message of client.iterMessages(entity as never, { limit: messagesPerDialog })) {
        const text = String((message as unknown as Record<string, unknown>).message ?? "").trim();
        if (!text) {
          continue;
        }
        const sender = await (message as unknown as { getSender?: () => Promise<unknown> }).getSender?.();
        summaries.push({
          id: String((message as unknown as Record<string, unknown>).id ?? ""),
          peerKey,
          chatId,
          chatTitle,
          chatUsername: username,
          senderLabel: titleFromEntity(sender),
          text,
          outgoing: Boolean((message as unknown as Record<string, unknown>).out),
          sentAt: Number(((message as unknown as Record<string, unknown>).date as Date | undefined)?.getTime() ?? Date.now()),
          permalink: buildPermalink(username, String((message as unknown as Record<string, unknown>).id ?? "")),
        });
        count += 1;
        if (count >= messagesPerDialog) {
          break;
        }
      }
    }
    return summaries;
  });
}

export async function searchTelegramMessages(
  config: SofiaAgentConfig,
  input: {
    query: string;
    targetChat?: string | null;
    limit: number;
  },
): Promise<SofiaTelegramMessageSummary[]> {
  return withSofiaTelegramClient(config, async (client) => {
    const summaries: SofiaTelegramMessageSummary[] = [];
    const entity = input.targetChat ? await client.getEntity(input.targetChat) : undefined;
    for await (const message of client.iterMessages(entity as never, {
      limit: input.limit,
      search: input.query,
    })) {
      const text = String((message as unknown as Record<string, unknown>).message ?? "").trim();
      if (!text) {
        continue;
      }
      const chat = await (message as unknown as { getChat?: () => Promise<unknown> }).getChat?.();
      const sender = await (message as unknown as { getSender?: () => Promise<unknown> }).getSender?.();
      const username = usernameFromEntity(chat);
      summaries.push({
        id: String((message as unknown as Record<string, unknown>).id ?? ""),
        peerKey: buildPeerKey(chat, input.targetChat ?? "global"),
        chatId: entityNumericId(chat),
        chatTitle: titleFromEntity(chat),
        chatUsername: username,
        senderLabel: titleFromEntity(sender),
        text,
        outgoing: Boolean((message as unknown as Record<string, unknown>).out),
        sentAt: Number(((message as unknown as Record<string, unknown>).date as Date | undefined)?.getTime() ?? Date.now()),
        permalink: buildPermalink(username, String((message as unknown as Record<string, unknown>).id ?? "")),
      });
    }
    return summaries;
  });
}

export async function sendTelegramText(
  config: SofiaAgentConfig,
  input: {
    targetChat: string;
    message: string;
    replyToMessageId?: number | null;
  },
): Promise<{ messageId: string }> {
  return withSofiaTelegramClient(config, async (client) => {
    const entity = await client.getEntity(input.targetChat);
    const result = await client.sendMessage(entity, {
      message: input.message,
      replyTo: input.replyToMessageId ?? undefined,
    });
    return {
      messageId: String(result.id),
    };
  });
}
