"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("./config");
const db_1 = require("./db");
const inbox_1 = require("./sofia_agent/inbox");
const mtproto_1 = require("./sofia_agent/mtproto");
const runtime_1 = require("./sofia_agent/runtime");
const scheduler_1 = require("./sofia_agent/scheduler");
function parseArgs(argv) {
    const [, , command = "", ...rest] = argv;
    const positionals = [];
    const flags = {};
    for (const token of rest) {
        if (token.startsWith("--")) {
            const [key, value = "true"] = token.slice(2).split("=", 2);
            flags[key] = value;
            continue;
        }
        positionals.push(token);
    }
    return { command, positionals, flags };
}
function requireFlag(flags, key) {
    const value = flags[key];
    if (!value || value === "true") {
        throw new Error(`Missing required flag --${key}=...`);
    }
    return value;
}
async function createTask(flags, positionals) {
    const taskType = (positionals[0] ?? "");
    const title = positionals.slice(1).join(" ").trim();
    if (!taskType || !title) {
        throw new Error("Usage: sofia:create-task <taskType> <title> [--channel=...] [--chat=...] [--topic=...] [--sourceText=...]");
    }
    const payload = {};
    for (const [key, value] of Object.entries(flags)) {
        if (key === "channel" || key === "chat") {
            continue;
        }
        payload[key] = value;
    }
    const row = await (0, db_1.createSofiaAgentTask)({
        taskType,
        title,
        sourceChannel: flags.channel ?? null,
        targetChat: flags.chat ?? null,
        payload,
    });
    process.stdout.write(`Created Sofia task #${row.id} (${row.taskType})\n`);
}
async function runOnce(config) {
    const processed = await (0, runtime_1.runSofiaGenerationBatch)(config, 1);
    process.stdout.write(processed > 0 ? `Draft ready for ${processed} Sofia task\n` : "No pending Sofia tasks\n");
}
async function listDrafts() {
    const drafts = await (0, db_1.listSofiaAgentDrafts)(20);
    if (drafts.length === 0) {
        process.stdout.write("No Sofia drafts yet\n");
        return;
    }
    for (const draft of drafts) {
        process.stdout.write(`#${draft.id} task=${draft.taskId} model=${draft.model ?? "n/a"} created=${new Date(draft.createdAt).toISOString()}\n${draft.draftText}\n\n`);
    }
}
async function ingestInbox(config) {
    const result = await (0, inbox_1.ingestSofiaInbox)(config);
    process.stdout.write(`Inbox ingested: threads=${result.threadsUpserted} new_messages=${result.newMessages} tasks_created=${result.tasksCreated}\n`);
}
async function schedulerOnce(config) {
    const result = await (0, scheduler_1.runSofiaSearchSchedulerOnce)(config);
    process.stdout.write(`Search scheduler: targets=${result.searchedTargets} tasks_created=${result.tasksCreated}\n`);
}
async function createSearchTarget(flags, positionals) {
    const label = positionals.join(" ").trim();
    if (!label) {
        throw new Error("Usage: sofia:add-search-target <label> --query=... [--chat=...] [--cadence=180]");
    }
    const query = requireFlag(flags, "query");
    const row = await (0, db_1.createSofiaSearchTarget)({
        label,
        query,
        targetChat: flags.chat ?? null,
        cadenceMinutes: flags.cadence ? Number(flags.cadence) : undefined,
        metadata: {
            createdFromCli: true,
        },
    });
    process.stdout.write(`Created Sofia search target #${row.id} (${row.label})\n`);
}
async function listSearchTargets() {
    const targets = await (0, db_1.listSofiaSearchTargets)(false);
    if (targets.length === 0) {
        process.stdout.write("No Sofia search targets configured\n");
        return;
    }
    for (const target of targets) {
        process.stdout.write(`#${target.id} ${target.label} | query=${target.query} | chat=${target.targetChat ?? "global"} | cadence=${target.cadenceMinutes}m | enabled=${target.enabled}\n`);
    }
}
async function approveTask(flags, positionals) {
    const idValue = positionals[0] ?? flags.id;
    if (!idValue) {
        throw new Error("Usage: sofia:approve-task <taskId>");
    }
    await (0, db_1.markSofiaAgentTaskApproved)(Number(idValue));
    process.stdout.write(`Approved Sofia task #${Number(idValue)}\n`);
}
async function sendApproved(config) {
    const sentCount = await (0, runtime_1.sendApprovedSofiaTasks)(config, 20);
    process.stdout.write(`Sent ${sentCount} approved Sofia task(s)\n`);
}
async function sessionCheck(config) {
    const self = await (0, mtproto_1.getSofiaSelf)(config);
    process.stdout.write(`MTProto OK: id=${self.id} username=${self.username ?? "n/a"} name=${[self.firstName, self.lastName].filter(Boolean).join(" ") || "n/a"}\n`);
}
async function listDialogs(config) {
    const dialogs = await (0, mtproto_1.listPrivateDialogs)(config, 20);
    if (dialogs.length === 0) {
        process.stdout.write("No private dialogs found\n");
        return;
    }
    for (const dialog of dialogs) {
        process.stdout.write(`${dialog.entityType} | ${dialog.title} | ${dialog.username ? `@${dialog.username}` : "no_username"} | ${dialog.peerKey}\n`);
    }
}
async function main() {
    const config = (0, config_1.loadSofiaAgentConfig)();
    (0, db_1.initDb)(config.databaseUrl);
    await (0, db_1.ensureSchema)();
    const { command, positionals, flags } = parseArgs(process.argv);
    if (command === "create-task") {
        await createTask(flags, positionals);
        return;
    }
    if (command === "run-once") {
        await runOnce(config);
        return;
    }
    if (command === "list-drafts") {
        await listDrafts();
        return;
    }
    if (command === "ingest-inbox") {
        await ingestInbox(config);
        return;
    }
    if (command === "scheduler-once") {
        await schedulerOnce(config);
        return;
    }
    if (command === "scheduler") {
        await (0, scheduler_1.startSofiaScheduler)(config);
        return;
    }
    if (command === "add-search-target") {
        await createSearchTarget(flags, positionals);
        return;
    }
    if (command === "list-search-targets") {
        await listSearchTargets();
        return;
    }
    if (command === "approve-task") {
        await approveTask(flags, positionals);
        return;
    }
    if (command === "send-approved") {
        await sendApproved(config);
        return;
    }
    if (command === "session-check") {
        await sessionCheck(config);
        return;
    }
    if (command === "list-private-dialogs") {
        await listDialogs(config);
        return;
    }
    process.stdout.write([
        "Sofia agent CLI",
        "Commands:",
        "  create-task <taskType> <title> [--channel=...] [--chat=...] [--topic=...] [--sourceText=...]",
        "  run-once",
        "  list-drafts",
        "  ingest-inbox",
        "  scheduler-once",
        "  scheduler",
        "  add-search-target <label> --query=... [--chat=...] [--cadence=180]",
        "  list-search-targets",
        "  approve-task <taskId>",
        "  send-approved",
        "  session-check",
        "  list-private-dialogs",
    ].join("\n") + "\n");
}
main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
    process.exitCode = 1;
});
