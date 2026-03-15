"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runSofiaSearchSchedulerOnce = runSofiaSearchSchedulerOnce;
exports.runSofiaSchedulerCycle = runSofiaSchedulerCycle;
exports.startSofiaScheduler = startSofiaScheduler;
const db_1 = require("../db");
const mtproto_1 = require("./mtproto");
const inbox_1 = require("./inbox");
const runtime_1 = require("./runtime");
function outreachTaskType(targetChat) {
    return targetChat ? "channel_comment" : "group_outreach";
}
async function runSofiaSearchSchedulerOnce(config) {
    const dueTargets = await (0, db_1.listDueSofiaSearchTargets)();
    let tasksCreated = 0;
    for (const target of dueTargets) {
        const matches = await (0, mtproto_1.searchTelegramMessages)(config, {
            query: target.query,
            targetChat: target.targetChat,
            limit: config.schedulerSearchLimit,
        });
        for (const match of matches) {
            if (match.outgoing) {
                continue;
            }
            const dedupKey = `search:${target.id}:${match.peerKey}:${match.id}`;
            const existing = await (0, db_1.findSofiaTaskByDedupKey)(dedupKey);
            if (existing) {
                continue;
            }
            await (0, db_1.createSofiaAgentTask)({
                taskType: outreachTaskType(target.targetChat),
                title: `${target.label}: ${match.chatTitle ?? "Telegram thread"}`,
                sourceChannel: match.chatUsername ? `@${match.chatUsername}` : match.chatTitle,
                targetChat: target.targetChat ?? (match.chatUsername ? `@${match.chatUsername}` : match.chatId),
                payload: {
                    dedupKey,
                    searchTargetId: target.id,
                    sourceText: match.text,
                    sourceMessageId: match.id,
                    sourcePermalink: match.permalink,
                    senderLabel: match.senderLabel,
                    searchQuery: target.query,
                    chatTitle: match.chatTitle,
                    chatUsername: match.chatUsername,
                    replyToMessageId: Number(match.id),
                },
            });
            tasksCreated += 1;
        }
        await (0, db_1.markSofiaSearchTargetChecked)(target.id);
    }
    return {
        searchedTargets: dueTargets.length,
        tasksCreated,
    };
}
async function runSofiaSchedulerCycle(config) {
    const inbox = await (0, inbox_1.ingestSofiaInbox)(config);
    const discovery = await runSofiaSearchSchedulerOnce(config);
    const draftsCreated = await (0, runtime_1.runSofiaGenerationBatch)(config, config.generationBatchSize);
    const sentCount = config.autoSendApproved ? await (0, runtime_1.sendApprovedSofiaTasks)(config, config.generationBatchSize) : 0;
    return {
        inboxTasksCreated: inbox.tasksCreated,
        outreachTasksCreated: discovery.tasksCreated,
        draftsCreated,
        sentCount,
    };
}
async function startSofiaScheduler(config) {
    const intervalMs = Math.max(1, config.schedulerPollMinutes) * 60 * 1000;
    const runCycle = async () => {
        const result = await runSofiaSchedulerCycle(config);
        process.stdout.write([
            `[${new Date().toISOString()}] Sofia scheduler cycle`,
            `  inbox_tasks=${result.inboxTasksCreated}`,
            `  outreach_tasks=${result.outreachTasksCreated}`,
            `  drafts=${result.draftsCreated}`,
            `  sent=${result.sentCount}`,
        ].join("\n") + "\n");
    };
    await runCycle();
    setInterval(() => {
        void runCycle().catch((error) => {
            process.stderr.write(`[${new Date().toISOString()}] Sofia scheduler failed: ${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
        });
    }, intervalMs);
}
