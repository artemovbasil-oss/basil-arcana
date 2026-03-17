import { Api, TelegramClient, utils } from "telegram";
import { StringSession } from "telegram/sessions";
import { Logger, LogLevel } from "telegram/extensions/Logger";
import bigInt from "big-integer";

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
  mediaKind: "photo" | "document" | "other" | null;
  outgoing: boolean;
  sentAt: number;
  permalink: string | null;
}

export interface SofiaResolvedCommunityTarget {
  requestedTarget: string;
  effectiveTarget: string;
  effectiveTitle: string | null;
  effectiveUsername: string | null;
  usedLinkedDiscussion: boolean;
  targetKind: "user" | "group" | "channel" | "unknown";
  isWritableCommunity: boolean;
}

interface SofiaResolvedUserDialog {
  peerKey: string;
  chatId: string;
  chatTitle: string;
  chatUsername: string | null;
  isBot: boolean;
  inputPeer: Api.InputPeerUser;
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

function isBotEntity(entity: unknown): boolean {
  if (!entity || typeof entity !== "object") {
    return false;
  }
  return (entity as Record<string, unknown>).bot === true;
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

function bigintString(value: unknown): string | null {
  if (typeof value === "bigint") {
    return value.toString();
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }
  return null;
}

function normalizeTimestamp(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value > 10_000_000_000 ? value : value * 1000;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === "bigint") {
    const num = Number(value);
    return Number.isFinite(num) ? normalizeTimestamp(num) : Date.now();
  }
  if (typeof value === "string" && value.trim()) {
    const asNumber = Number(value);
    if (Number.isFinite(asNumber)) {
      return normalizeTimestamp(asNumber);
    }
    const asDate = Date.parse(value);
    if (Number.isFinite(asDate)) {
      return asDate;
    }
  }
  return Date.now();
}

function detectMediaKind(message: Record<string, unknown>): SofiaTelegramMessageSummary["mediaKind"] {
  const media = message.media;
  if (!media || typeof media !== "object") {
    return null;
  }
  const className = String((media as Record<string, unknown>).className ?? "");
  if (className.includes("Photo")) {
    return "photo";
  }
  if (className.includes("Document")) {
    return "document";
  }
  return "other";
}

function getEntityMap(result: { users?: unknown[]; chats?: unknown[] }): Map<string, Record<string, unknown>> {
  const entities = new Map<string, Record<string, unknown>>();
  for (const entity of [...(result.users ?? []), ...(result.chats ?? [])]) {
    if (!entity || typeof entity !== "object") {
      continue;
    }
    try {
      entities.set(utils.getPeerId(entity as never).toString(), entity as Record<string, unknown>);
    } catch {
      continue;
    }
  }
  return entities;
}

async function getPrivateDialogsRaw(
  client: TelegramClient,
  limit: number,
): Promise<SofiaResolvedUserDialog[]> {
  const dialogs = await client.invoke(
    new Api.messages.GetDialogs({
      offsetDate: 0,
      offsetId: 0,
      offsetPeer: new Api.InputPeerEmpty(),
      limit,
      hash: bigInt.zero,
    }),
  );

  const entities = getEntityMap(dialogs as { users?: unknown[]; chats?: unknown[] });
  const results: SofiaResolvedUserDialog[] = [];

  for (const dialog of (dialogs as { dialogs?: unknown[] }).dialogs ?? []) {
    if (!(dialog instanceof Api.Dialog)) {
      continue;
    }
    if (!(dialog.peer instanceof Api.PeerUser)) {
      continue;
    }
    const peerId = utils.getPeerId(dialog.peer).toString();
    const entity = entities.get(peerId);
    if (!entity) {
      continue;
    }
    const user = entity as Record<string, unknown>;
    const userId = user.id;
    const accessHash = user.accessHash;
    if (typeof userId === "undefined" || typeof accessHash === "undefined") {
      continue;
    }
    if (isBotEntity(entity)) {
      continue;
    }

    results.push({
      peerKey: buildPeerKey(entity, peerId),
      chatId: entityNumericId(entity) ?? peerId,
      chatTitle: titleFromEntity(entity),
      chatUsername: usernameFromEntity(entity),
      isBot: false,
      inputPeer: new Api.InputPeerUser({
        userId: bigInt(String(userId)),
        accessHash: bigInt(String(accessHash)),
      }),
    });
  }

  return results;
}

export async function withSofiaTelegramClient<T>(
  config: SofiaAgentConfig,
  fn: (client: TelegramClient) => Promise<T>,
): Promise<T> {
  const { apiId, apiHash, sessionString } = requireMtprotoConfig(config);
  const client = new TelegramClient(new StringSession(sessionString), apiId, apiHash, {
    connectionRetries: 5,
    baseLogger: new Logger(LogLevel.NONE),
  });
  client.setLogLevel(LogLevel.NONE);
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
    const dialogs = await getPrivateDialogsRaw(client, limit);
    return dialogs.map((dialog) => ({
      peerKey: dialog.peerKey,
      title: dialog.chatTitle,
      username: dialog.chatUsername,
      entityType: "user",
    }));
  });
}

export async function fetchRecentPrivateMessages(
  config: SofiaAgentConfig,
  limitDialogs: number,
  messagesPerDialog: number,
): Promise<SofiaTelegramMessageSummary[]> {
  return withSofiaTelegramClient(config, async (client) => {
    const summaries: SofiaTelegramMessageSummary[] = [];
    const dialogs = await getPrivateDialogsRaw(client, limitDialogs);
    for (const dialog of dialogs) {
      const history = await client.invoke(
        new Api.messages.GetHistory({
          peer: dialog.inputPeer,
          offsetId: 0,
          offsetDate: 0,
          addOffset: 0,
          limit: messagesPerDialog,
          maxId: 0,
          minId: 0,
          hash: bigInt.zero,
        }),
      );

      for (const message of (history as { messages?: unknown[] }).messages ?? []) {
        if (!(message instanceof Api.Message)) {
          continue;
        }
        const rawMessage = message as unknown as Record<string, unknown>;
        const mediaKind = detectMediaKind(rawMessage);
        const text = String(rawMessage.message ?? "").trim();
        const normalizedText =
          text ||
          (mediaKind === "photo"
            ? "[photo attachment without caption]"
            : mediaKind === "document"
              ? "[document attachment without caption]"
              : mediaKind
                ? "[attachment without caption]"
                : "");
        if (!normalizedText) {
          continue;
        }

        summaries.push({
          id: String(rawMessage.id ?? ""),
          peerKey: dialog.peerKey,
          chatId: dialog.chatId,
          chatTitle: dialog.chatTitle,
          chatUsername: dialog.chatUsername,
          senderLabel: Boolean(rawMessage.out) ? "Sofia Knox" : dialog.chatTitle,
          text: normalizedText,
          mediaKind,
          outgoing: Boolean(rawMessage.out),
          sentAt: normalizeTimestamp(rawMessage.date),
          permalink: buildPermalink(dialog.chatUsername, String(rawMessage.id ?? "")),
        });
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
    const query = input.query.trim();
    const iterOptions = query
      ? { limit: input.limit, search: query }
      : { limit: input.limit };
    for await (const message of client.iterMessages(entity as never, iterOptions as never)) {
      const rawMessage = message as unknown as Record<string, unknown>;
      const text = String(rawMessage.message ?? "").trim();
      if (!text) {
        continue;
      }
      const chat = await (message as unknown as { getChat?: () => Promise<unknown> }).getChat?.();
      const sender = await (message as unknown as { getSender?: () => Promise<unknown> }).getSender?.();
      const username = usernameFromEntity(chat);
      summaries.push({
        id: String(rawMessage.id ?? ""),
        peerKey: buildPeerKey(chat, input.targetChat ?? "global"),
        chatId: entityNumericId(chat),
        chatTitle: titleFromEntity(chat),
        chatUsername: username,
        senderLabel: titleFromEntity(sender),
        text,
        mediaKind: detectMediaKind(rawMessage),
        outgoing: Boolean(rawMessage.out),
        sentAt: normalizeTimestamp(rawMessage.date),
        permalink: buildPermalink(username, String(rawMessage.id ?? "")),
      });
    }
    return summaries;
  });
}

export async function resolveCommunityTarget(
  config: SofiaAgentConfig,
  targetChat: string,
): Promise<SofiaResolvedCommunityTarget> {
  return withSofiaTelegramClient(config, async (client) => {
    const entity = await client.getEntity(targetChat);
    const requestedUsername = usernameFromEntity(entity);
    const requestedTitle = titleFromEntity(entity);
    const entityRecord = entity as unknown as Record<string, unknown>;
    const className = String(entityRecord.className ?? "");
    const isMegaGroup = entityRecord.megagroup === true || entityRecord.gigagroup === true;
    const isBroadcastChannel = entityRecord.broadcast === true;

    if (className !== "Channel") {
      return {
        requestedTarget: targetChat,
        effectiveTarget: targetChat,
        effectiveTitle: requestedTitle,
        effectiveUsername: requestedUsername,
        usedLinkedDiscussion: false,
        targetKind: "group",
        isWritableCommunity: true,
      };
    }

    if (isMegaGroup || !isBroadcastChannel) {
      return {
        requestedTarget: targetChat,
        effectiveTarget: targetChat,
        effectiveTitle: requestedTitle,
        effectiveUsername: requestedUsername,
        usedLinkedDiscussion: false,
        targetKind: "group",
        isWritableCommunity: true,
      };
    }

    const inputChannel = await client.getInputEntity(entity);
    const full = await client.invoke(
      new Api.channels.GetFullChannel({
        channel: inputChannel as unknown as Api.TypeInputChannel,
      }),
    );
    const fullChatRecord = full.fullChat as unknown as Record<string, unknown>;
    const linkedChatId = bigintString(fullChatRecord.linkedChatId);
    if (!linkedChatId) {
      return {
        requestedTarget: targetChat,
        effectiveTarget: targetChat,
        effectiveTitle: requestedTitle,
        effectiveUsername: requestedUsername,
        usedLinkedDiscussion: false,
        targetKind: "channel",
        isWritableCommunity: false,
      };
    }

    const linkedEntity = (full.chats ?? []).find(
      (chat) => bigintString((chat as unknown as Record<string, unknown>).id) === linkedChatId,
    );
    if (!linkedEntity) {
      return {
        requestedTarget: targetChat,
        effectiveTarget: targetChat,
        effectiveTitle: requestedTitle,
        effectiveUsername: requestedUsername,
        usedLinkedDiscussion: false,
        targetKind: "channel",
        isWritableCommunity: false,
      };
    }

    const linkedUsername = usernameFromEntity(linkedEntity);
    const linkedTitle = titleFromEntity(linkedEntity);
    const linkedNumericId = entityNumericId(linkedEntity);
    const effectiveTarget = linkedUsername ? `@${linkedUsername}` : linkedNumericId ?? targetChat;
    return {
      requestedTarget: targetChat,
      effectiveTarget,
      effectiveTitle: linkedTitle,
      effectiveUsername: linkedUsername,
      usedLinkedDiscussion: effectiveTarget !== targetChat,
      targetKind: "channel",
      isWritableCommunity: true,
    };
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
