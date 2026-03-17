"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runSofiaGenerationBatch = runSofiaGenerationBatch;
exports.sendApprovedSofiaTasks = sendApprovedSofiaTasks;
const db_1 = require("../db");
const openai_1 = require("./openai");
const persona_1 = require("./persona");
const prompts_1 = require("./prompts");
const mtproto_1 = require("./mtproto");
function isInboxTask(taskType) {
    return taskType === "dm_reply" || taskType === "natal_chart_reply";
}
function isCommunityTask(taskType) {
    return taskType === "channel_comment" || taskType === "group_outreach";
}
function isOwnedChannelPostTask(taskType) {
    return taskType === "channel_post";
}
function isSocialCommunityTask(task) {
    return isCommunityTask(task.taskType) && task.payload.category === "social";
}
function normalizeHandle(value) {
    if (!value) {
        return null;
    }
    const trimmed = value.trim();
    if (!trimmed) {
        return null;
    }
    return trimmed.startsWith("@") ? trimmed.toLowerCase() : `@${trimmed.toLowerCase()}`;
}
function isCommunityAccessLossError(error) {
    const message = error instanceof Error ? error.message : String(error);
    return /CHANNEL_PRIVATE|CHAT_ADMIN_REQUIRED|CHAT_FORBIDDEN|CHAT_WRITE_FORBIDDEN|CHANNEL_INVALID|USER_BANNED_IN_CHANNEL|PEER_ID_INVALID/i.test(message);
}
function isAllowedTask(taskType, config) {
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
function buildImmediateCommunityReport(task, draftText) {
    const where = task.sourceChannel || task.targetChat || task.title;
    const sourceText = typeof task.payload.sourceText === "string" ? task.payload.sourceText.trim() : "";
    const sourcePermalink = typeof task.payload.sourcePermalink === "string" ? task.payload.sourcePermalink : null;
    const replyToMessageId = typeof task.payload.replyToMessageId === "number"
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
function buildConversationContext(messages) {
    return messages
        .map((message) => {
        const speaker = message.direction === "outbound"
            ? "Sofia"
            : (message.senderLabel?.trim() || "User");
        const timestamp = new Date(message.sentAt).toISOString().replace("T", " ").slice(0, 16);
        return `[${timestamp}] ${speaker}: ${message.messageText}`;
    })
        .join("\n");
}
function buildReplyGuidance(task, taskType, messages, recommendBotUrl) {
    const now = Date.now();
    const recentWindowMs = 24 * 60 * 60 * 1000;
    const recentOutbound = messages.filter((message) => message.direction === "outbound");
    const recentBotMention = recentOutbound.some((message) => now - message.sentAt <= recentWindowMs &&
        (message.messageText.includes(recommendBotUrl) || message.messageText.includes("@tarot_arkana_bot")));
    const targetHandle = normalizeHandle(typeof task.payload.effectiveTargetChat === "string"
        ? task.payload.effectiveTargetChat
        : typeof task.payload.requestedTargetChat === "string"
            ? task.payload.requestedTargetChat
            : null) ?? normalizeHandle(task.targetChat);
    const rules = [];
    if (isInboxTask(taskType)) {
        if (recentOutbound.length === 0) {
            rules.push(`If it feels natural in this first reply, you may softly mention the Tarot Arkana bot once: ${recommendBotUrl}. Present it as an optional helpful tool, not a pushy CTA.`);
        }
        else if (!recentBotMention) {
            rules.push(`You may occasionally recommend ${recommendBotUrl} only if it directly helps the user's question. Do not force it, and do not mention it more than once per 24 hours in the same thread.`);
        }
        else {
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
        }
        else {
            rules.push(`Mention ${recommendBotUrl} only if the conversation is explicitly about where to get a personal reading, a tarot spread, or a horoscope tool. If you mention it, do it briefly at the end, frame it as a genuinely useful self-reflection tool rather than an ad, and only once.`);
        }
    }
    if (isOwnedChannelPostTask(taskType)) {
        rules.push("Write in a channel-author voice: distinct, authored, and worth reading.");
        rules.push("Keep it original and avoid generic horoscope filler.");
        rules.push("For @estartarot, write in Russian.");
        rules.push(`You may softly mention ${recommendBotUrl} only if it fits the post organically, ideally as an optional tool rather than a CTA-heavy promo.`);
    }
    return rules.length ? rules.map((rule) => `- ${rule}`).join("\n") : undefined;
}
async function runSofiaGenerationBatch(config, limit = config.generationBatchSize) {
    if (!config.openAiApiKey) {
        throw new Error("OPENAI_API_KEY is required for Sofia generation");
    }
    const batchSize = Math.max(1, Math.min(20, limit));
    let processed = 0;
    for (let index = 0; index < batchSize; index += 1) {
        const task = await (0, db_1.claimNextSofiaAgentTask)();
        if (!task) {
            break;
        }
        if (!isAllowedTask(task.taskType, config)) {
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, `Task type ${task.taskType} is disabled in current mode`);
            continue;
        }
        try {
            const systemPrompt = (0, persona_1.buildSofiaSystemPrompt)(config.personaDisplayName, config.personaHandle);
            const persona = (0, persona_1.buildSofiaPersonaProfile)(config.personaDisplayName, config.personaHandle);
            const threadId = typeof task.payload.threadId === "number"
                ? task.payload.threadId
                : Number(task.payload.threadId);
            const contextMessages = Number.isFinite(threadId)
                ? await (0, db_1.listSofiaThreadMessages)(threadId, 14)
                : [];
            const prompt = (0, prompts_1.buildSofiaTaskPrompt)(task, contextMessages.length ? buildConversationContext(contextMessages) : undefined, buildReplyGuidance(task, task.taskType, contextMessages, config.recommendBotUrl));
            const result = await (0, openai_1.generateSofiaDraft)({
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
            await (0, db_1.saveSofiaAgentDraft)({
                taskId: task.id,
                draftText: result.draftText,
                model: config.openAiModel,
                notes,
            });
            if (isInboxTask(task.taskType) ||
                isSocialCommunityTask(task) ||
                (config.ownedChannelEnabled && isOwnedChannelPostTask(task.taskType))) {
                await (0, db_1.markSofiaAgentTaskApproved)(task.id);
            }
            processed += 1;
        }
        catch (error) {
            const searchTargetId = typeof task.payload.searchTargetId === "number"
                ? task.payload.searchTargetId
                : Number(task.payload.searchTargetId);
            if (Number.isFinite(searchTargetId) && isCommunityTask(task.taskType) && isCommunityAccessLossError(error)) {
                await (0, db_1.setSofiaSearchTargetEnabled)(searchTargetId, false, {
                    disabledReason: "access_lost",
                    disabledAt: new Date().toISOString(),
                    accessError: error instanceof Error ? error.message : String(error),
                });
            }
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, error instanceof Error ? error.message : String(error));
        }
    }
    return processed;
}
async function sendApprovedSofiaTasks(config, limit = 10) {
    const tasks = await (0, db_1.listSofiaAgentTasksByStatus)("approved", limit);
    let sentCount = 0;
    for (const task of tasks) {
        if (!isAllowedTask(task.taskType, config)) {
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, `Task type ${task.taskType} is disabled in current mode`);
            continue;
        }
        if (!task.targetChat) {
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, "Approved task is missing targetChat");
            continue;
        }
        const latestDraft = await (0, db_1.getLatestDraftForTask)(task.id);
        if (!latestDraft) {
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, "Approved task has no draft");
            continue;
        }
        try {
            const replyToMessageId = typeof task.payload.replyToMessageId === "number"
                ? task.payload.replyToMessageId
                : task.payload.replyToMessageId
                    ? Number(task.payload.replyToMessageId)
                    : null;
            const sent = await (0, mtproto_1.sendTelegramText)(config, {
                targetChat: task.targetChat,
                message: latestDraft.draftText,
                replyToMessageId: Number.isFinite(replyToMessageId) ? replyToMessageId : null,
            });
            const threadId = typeof task.payload.threadId === "number"
                ? task.payload.threadId
                : Number(task.payload.threadId);
            if (Number.isFinite(threadId)) {
                await (0, db_1.createSofiaAgentMessage)({
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
            await (0, db_1.markSofiaAgentTaskSent)(task.id, `telegram_message_id=${sent.messageId}`);
            if (isCommunityTask(task.taskType) && config.outreachReportEnabled && config.outreachReportChat) {
                await (0, mtproto_1.sendTelegramText)(config, {
                    targetChat: config.outreachReportChat,
                    message: buildImmediateCommunityReport(task, latestDraft.draftText),
                });
            }
            sentCount += 1;
        }
        catch (error) {
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, error instanceof Error ? error.message : String(error));
        }
    }
    return sentCount;
}
