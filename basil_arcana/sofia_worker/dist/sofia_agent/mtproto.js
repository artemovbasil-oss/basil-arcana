"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.withSofiaTelegramClient = withSofiaTelegramClient;
exports.getSofiaSelf = getSofiaSelf;
exports.listPrivateDialogs = listPrivateDialogs;
exports.fetchRecentPrivateMessages = fetchRecentPrivateMessages;
exports.searchTelegramMessages = searchTelegramMessages;
exports.sendTelegramText = sendTelegramText;
const telegram_1 = require("telegram");
const sessions_1 = require("telegram/sessions");
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
async function withSofiaTelegramClient(config, fn) {
    const { apiId, apiHash, sessionString } = requireMtprotoConfig(config);
    const client = new telegram_1.TelegramClient(new sessions_1.StringSession(sessionString), apiId, apiHash, {
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
        const results = [];
        for await (const dialog of client.iterDialogs({ limit })) {
            if (!dialog.isUser) {
                continue;
            }
            const entity = dialog.entity;
            results.push({
                peerKey: buildPeerKey(entity, String(dialog.id ?? "dialog")),
                title: titleFromEntity(entity),
                username: usernameFromEntity(entity),
                entityType: "user",
            });
        }
        return results;
    });
}
async function fetchRecentPrivateMessages(config, limitDialogs, messagesPerDialog) {
    return withSofiaTelegramClient(config, async (client) => {
        const summaries = [];
        for await (const dialog of client.iterDialogs({ limit: limitDialogs })) {
            if (!dialog.isUser) {
                continue;
            }
            const entity = dialog.entity;
            const username = usernameFromEntity(entity);
            const peerKey = buildPeerKey(entity, String(dialog.id ?? "dialog"));
            const chatId = entityNumericId(entity);
            const chatTitle = titleFromEntity(entity);
            let count = 0;
            for await (const message of client.iterMessages(entity, { limit: messagesPerDialog })) {
                const text = String(message.message ?? "").trim();
                if (!text) {
                    continue;
                }
                const sender = await message.getSender?.();
                summaries.push({
                    id: String(message.id ?? ""),
                    peerKey,
                    chatId,
                    chatTitle,
                    chatUsername: username,
                    senderLabel: titleFromEntity(sender),
                    text,
                    outgoing: Boolean(message.out),
                    sentAt: Number(message.date?.getTime() ?? Date.now()),
                    permalink: buildPermalink(username, String(message.id ?? "")),
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
async function searchTelegramMessages(config, input) {
    return withSofiaTelegramClient(config, async (client) => {
        const summaries = [];
        const entity = input.targetChat ? await client.getEntity(input.targetChat) : undefined;
        for await (const message of client.iterMessages(entity, {
            limit: input.limit,
            search: input.query,
        })) {
            const text = String(message.message ?? "").trim();
            if (!text) {
                continue;
            }
            const chat = await message.getChat?.();
            const sender = await message.getSender?.();
            const username = usernameFromEntity(chat);
            summaries.push({
                id: String(message.id ?? ""),
                peerKey: buildPeerKey(chat, input.targetChat ?? "global"),
                chatId: entityNumericId(chat),
                chatTitle: titleFromEntity(chat),
                chatUsername: username,
                senderLabel: titleFromEntity(sender),
                text,
                outgoing: Boolean(message.out),
                sentAt: Number(message.date?.getTime() ?? Date.now()),
                permalink: buildPermalink(username, String(message.id ?? "")),
            });
        }
        return summaries;
    });
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
