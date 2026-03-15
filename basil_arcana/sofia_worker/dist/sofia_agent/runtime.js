"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runSofiaGenerationBatch = runSofiaGenerationBatch;
exports.sendApprovedSofiaTasks = sendApprovedSofiaTasks;
const db_1 = require("../db");
const openai_1 = require("./openai");
const persona_1 = require("./persona");
const prompts_1 = require("./prompts");
const mtproto_1 = require("./mtproto");
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
        try {
            const systemPrompt = (0, persona_1.buildSofiaSystemPrompt)(config.personaDisplayName, config.personaHandle);
            const persona = (0, persona_1.buildSofiaPersonaProfile)(config.personaDisplayName, config.personaHandle);
            const prompt = (0, prompts_1.buildSofiaTaskPrompt)(task);
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
            processed += 1;
        }
        catch (error) {
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, error instanceof Error ? error.message : String(error));
        }
    }
    return processed;
}
async function sendApprovedSofiaTasks(config, limit = 10) {
    const tasks = await (0, db_1.listSofiaAgentTasksByStatus)("approved", limit);
    let sentCount = 0;
    for (const task of tasks) {
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
            await (0, db_1.markSofiaAgentTaskSent)(task.id, `telegram_message_id=${sent.messageId}`);
            sentCount += 1;
        }
        catch (error) {
            await (0, db_1.markSofiaAgentTaskFailed)(task.id, error instanceof Error ? error.message : String(error));
        }
    }
    return sentCount;
}
