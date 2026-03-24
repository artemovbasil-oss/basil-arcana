"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.withSofiaTelegramClient = withSofiaTelegramClient;
exports.getSofiaSelf = getSofiaSelf;
exports.listPrivateDialogs = listPrivateDialogs;
exports.fetchRecentPrivateMessages = fetchRecentPrivateMessages;
exports.searchTelegramMessagesWithClient = searchTelegramMessagesWithClient;
exports.searchTelegramMessages = searchTelegramMessages;
exports.fetchTelegramMessageWindowWithClient = fetchTelegramMessageWindowWithClient;
exports.fetchTelegramMessageWindow = fetchTelegramMessageWindow;
exports.resolveCommunityTargetWithClient = resolveCommunityTargetWithClient;
exports.resolveCommunityTarget = resolveCommunityTarget;
exports.sendTelegramText = sendTelegramText;
const telegram_1 = require("telegram");
const sessions_1 = require("telegram/sessions");
const Logger_1 = require("telegram/extensions/Logger");
const big_integer_1 = __importDefault(require("big-integer"));
function requireMtprotoConfig(config) {
    if (!config.telegramApiId || !config.telegramApiHash || !config.telegramSessionString) {
        throw new Error("MTProto is not configured. Set TELEGRAM_API_ID, TELEGRAM_API_HASH, and SOFIA_SESSION_STRING.");
    }
    return {
        apiId: config.telegramApiId,
        apiHash: config.telegramApiHash,
        sessionString: config.telegramSessionString,
    };
}
function titleFromEntity(entity) {
    if (!entity || typeof entity !== "object") {
        return "Unknown";
    }
    const record = entity;
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
function usernameFromEntity(entity) {
    if (!entity || typeof entity !== "object") {
        return null;
    }
    const value = entity.username;
    return typeof value === "string" && value.trim() ? value.trim() : null;
}
function isBotEntity(entity) {
    if (!entity || typeof entity !== "object") {
        return false;
    }
    return entity.bot === true;
}
function entityTypeFromDialog(dialog) {
    if (!dialog || typeof dialog !== "object") {
        return "unknown";
    }
    const record = dialog;
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
function buildPeerKey(entity, fallback) {
    if (!entity || typeof entity !== "object") {
        return fallback;
    }
    const record = entity;
    const className = typeof record.className === "string" ? record.className : "peer";
    const id = record.id;
    const idValue = typeof id === "bigint" ? id.toString() : String(id ?? fallback);
    return `${className}:${idValue}`;
}
function entityNumericId(entity) {
    if (!entity || typeof entity !== "object") {
        return null;
    }
    const id = entity.id;
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
function buildPermalink(username, messageId) {
    if (!username) {
        return null;
    }
    return `https://t.me/${username}/${messageId}`;
}
function bigintString(value) {
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
function normalizeTimestamp(value) {
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
function detectMediaKind(message) {
    const media = message.media;
    if (!media || typeof media !== "object") {
        return null;
    }
    const className = String(media.className ?? "");
    if (className.includes("Photo")) {
        return "photo";
    }
    if (className.includes("Document")) {
        return "document";
    }
    return "other";
}
function getEntityMap(result) {
    const entities = new Map();
    for (const entity of [...(result.users ?? []), ...(result.chats ?? [])]) {
        if (!entity || typeof entity !== "object") {
            continue;
        }
        try {
            entities.set(telegram_1.utils.getPeerId(entity).toString(), entity);
        }
        catch {
            continue;
        }
    }
    return entities;
}
async function getPrivateDialogsRaw(client, limit) {
    const dialogs = await client.invoke(new telegram_1.Api.messages.GetDialogs({
        offsetDate: 0,
        offsetId: 0,
        offsetPeer: new telegram_1.Api.InputPeerEmpty(),
        limit,
        hash: big_integer_1.default.zero,
    }));
    const entities = getEntityMap(dialogs);
    const results = [];
    for (const dialog of dialogs.dialogs ?? []) {
        if (!(dialog instanceof telegram_1.Api.Dialog)) {
            continue;
        }
        if (!(dialog.peer instanceof telegram_1.Api.PeerUser)) {
            continue;
        }
        const peerId = telegram_1.utils.getPeerId(dialog.peer).toString();
        const entity = entities.get(peerId);
        if (!entity) {
            continue;
        }
        const user = entity;
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
            inputPeer: new telegram_1.Api.InputPeerUser({
                userId: (0, big_integer_1.default)(String(userId)),
                accessHash: (0, big_integer_1.default)(String(accessHash)),
            }),
        });
    }
    return results;
}
async function withSofiaTelegramClient(config, fn) {
    const { apiId, apiHash, sessionString } = requireMtprotoConfig(config);
    const client = new telegram_1.TelegramClient(new sessions_1.StringSession(sessionString), apiId, apiHash, {
        connectionRetries: 5,
        baseLogger: new Logger_1.Logger(Logger_1.LogLevel.NONE),
    });
    client.setLogLevel(Logger_1.LogLevel.NONE);
    await client.connect();
    const authorized = await client.checkAuthorization();
    if (!authorized) {
        await client.disconnect();
        throw new Error("SOFIA_SESSION_STRING is present but not authorized. Refresh the Telegram user session.");
    }
    try {
        return await fn(client);
    }
    finally {
        await client.disconnect();
    }
}
async function getSofiaSelf(config) {
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
async function listPrivateDialogs(config, limit) {
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
async function fetchRecentPrivateMessages(config, limitDialogs, messagesPerDialog) {
    return withSofiaTelegramClient(config, async (client) => {
        const summaries = [];
        const dialogs = await getPrivateDialogsRaw(client, limitDialogs);
        for (const dialog of dialogs) {
            const history = await client.invoke(new telegram_1.Api.messages.GetHistory({
                peer: dialog.inputPeer,
                offsetId: 0,
                offsetDate: 0,
                addOffset: 0,
                limit: messagesPerDialog,
                maxId: 0,
                minId: 0,
                hash: big_integer_1.default.zero,
            }));
            for (const message of history.messages ?? []) {
                if (!(message instanceof telegram_1.Api.Message)) {
                    continue;
                }
                const rawMessage = message;
                const mediaKind = detectMediaKind(rawMessage);
                const text = String(rawMessage.message ?? "").trim();
                const normalizedText = text ||
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
async function searchTelegramMessagesWithClient(client, input) {
    const summaries = [];
    const entity = input.targetChat ? await client.getEntity(input.targetChat) : undefined;
    const query = input.query.trim();
    const iterOptions = query
        ? { limit: input.limit, search: query }
        : { limit: input.limit };
    for await (const message of client.iterMessages(entity, iterOptions)) {
        const rawMessage = message;
        const text = String(rawMessage.message ?? "").trim();
        if (!text) {
            continue;
        }
        const chat = await message.getChat?.();
        const sender = await message.getSender?.();
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
}
async function searchTelegramMessages(config, input) {
    return withSofiaTelegramClient(config, async (client) => searchTelegramMessagesWithClient(client, input));
}
async function fetchTelegramMessageWindowWithClient(client, input) {
    if (!input.targetChat || !Number.isFinite(input.centerMessageId)) {
        return [];
    }
    const before = Math.max(0, input.before ?? 3);
    const after = Math.max(0, input.after ?? 3);
    const entity = await client.getEntity(input.targetChat);
    const inputPeer = await client.getInputEntity(entity);
    const history = await client.invoke(new telegram_1.Api.messages.GetHistory({
        peer: inputPeer,
        offsetId: input.centerMessageId,
        offsetDate: 0,
        addOffset: -before,
        limit: before + after + 1,
        maxId: 0,
        minId: 0,
        hash: big_integer_1.default.zero,
    }));
    const chat = await client.getEntity(input.targetChat);
    const items = [];
    for (const message of history.messages ?? []) {
        if (!(message instanceof telegram_1.Api.Message)) {
            continue;
        }
        const rawMessage = message;
        const text = String(rawMessage.message ?? "").trim();
        if (!text) {
            continue;
        }
        const sender = await message.getSender?.();
        items.push({
            id: String(rawMessage.id ?? ""),
            senderLabel: titleFromEntity(sender ?? chat),
            text,
            outgoing: Boolean(rawMessage.out),
            sentAt: normalizeTimestamp(rawMessage.date),
        });
    }
    return items.sort((a, b) => a.sentAt - b.sentAt);
}
async function fetchTelegramMessageWindow(config, input) {
    return withSofiaTelegramClient(config, async (client) => fetchTelegramMessageWindowWithClient(client, input));
}
async function resolveCommunityTargetWithClient(client, targetChat) {
    const entity = await client.getEntity(targetChat);
    const requestedUsername = usernameFromEntity(entity);
    const requestedTitle = titleFromEntity(entity);
    const entityRecord = entity;
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
    const full = await client.invoke(new telegram_1.Api.channels.GetFullChannel({
        channel: inputChannel,
    }));
    const fullChatRecord = full.fullChat;
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
    const linkedEntity = (full.chats ?? []).find((chat) => bigintString(chat.id) === linkedChatId);
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
}
async function resolveCommunityTarget(config, targetChat) {
    return withSofiaTelegramClient(config, async (client) => resolveCommunityTargetWithClient(client, targetChat));
}
async function sendTelegramText(config, input) {
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
