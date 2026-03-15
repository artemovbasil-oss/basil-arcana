import { loadSofiaAgentConfig } from "./config";
import {
  createSofiaSearchTarget,
  createSofiaAgentTask,
  ensureSchema,
  initDb,
  listSofiaAgentDrafts,
  listSofiaSearchTargets,
  markSofiaAgentTaskApproved,
  type SofiaAgentTaskInput,
} from "./db";
import { ingestSofiaInbox } from "./sofia_agent/inbox";
import { getSofiaSelf, listPrivateDialogs } from "./sofia_agent/mtproto";
import { runSofiaGenerationBatch, sendApprovedSofiaTasks } from "./sofia_agent/runtime";
import { runSofiaSearchSchedulerOnce, startSofiaScheduler } from "./sofia_agent/scheduler";

function parseArgs(argv: string[]): { command: string; positionals: string[]; flags: Record<string, string> } {
  const [, , command = "", ...rest] = argv;
  const positionals: string[] = [];
  const flags: Record<string, string> = {};
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

function requireFlag(flags: Record<string, string>, key: string): string {
  const value = flags[key];
  if (!value || value === "true") {
    throw new Error(`Missing required flag --${key}=...`);
  }
  return value;
}

async function createTask(flags: Record<string, string>, positionals: string[]): Promise<void> {
  const taskType = (positionals[0] ?? "") as SofiaAgentTaskInput["taskType"];
  const title = positionals.slice(1).join(" ").trim();
  if (!taskType || !title) {
    throw new Error("Usage: sofia:create-task <taskType> <title> [--channel=...] [--chat=...] [--topic=...] [--sourceText=...]");
  }
  const payload: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(flags)) {
    if (key === "channel" || key === "chat") {
      continue;
    }
    payload[key] = value;
  }
  const row = await createSofiaAgentTask({
    taskType,
    title,
    sourceChannel: flags.channel ?? null,
    targetChat: flags.chat ?? null,
    payload,
  });
  process.stdout.write(`Created Sofia task #${row.id} (${row.taskType})\n`);
}

async function runOnce(config: ReturnType<typeof loadSofiaAgentConfig>): Promise<void> {
  const processed = await runSofiaGenerationBatch(config, 1);
  process.stdout.write(processed > 0 ? `Draft ready for ${processed} Sofia task\n` : "No pending Sofia tasks\n");
}

async function listDrafts(): Promise<void> {
  const drafts = await listSofiaAgentDrafts(20);
  if (drafts.length === 0) {
    process.stdout.write("No Sofia drafts yet\n");
    return;
  }
  for (const draft of drafts) {
    process.stdout.write(
      `#${draft.id} task=${draft.taskId} model=${draft.model ?? "n/a"} created=${new Date(draft.createdAt).toISOString()}\n${draft.draftText}\n\n`,
    );
  }
}

async function ingestInbox(config: ReturnType<typeof loadSofiaAgentConfig>): Promise<void> {
  const result = await ingestSofiaInbox(config);
  process.stdout.write(
    `Inbox ingested: threads=${result.threadsUpserted} new_messages=${result.newMessages} tasks_created=${result.tasksCreated}\n`,
  );
}

async function schedulerOnce(config: ReturnType<typeof loadSofiaAgentConfig>): Promise<void> {
  const result = await runSofiaSearchSchedulerOnce(config);
  process.stdout.write(
    `Search scheduler: targets=${result.searchedTargets} tasks_created=${result.tasksCreated}\n`,
  );
}

async function createSearchTarget(flags: Record<string, string>, positionals: string[]): Promise<void> {
  const label = positionals.join(" ").trim();
  if (!label) {
    throw new Error("Usage: sofia:add-search-target <label> --query=... [--chat=...] [--cadence=180]");
  }
  const query = requireFlag(flags, "query");
  const row = await createSofiaSearchTarget({
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

async function listSearchTargets(): Promise<void> {
  const targets = await listSofiaSearchTargets(false);
  if (targets.length === 0) {
    process.stdout.write("No Sofia search targets configured\n");
    return;
  }
  for (const target of targets) {
    process.stdout.write(
      `#${target.id} ${target.label} | query=${target.query} | chat=${target.targetChat ?? "global"} | cadence=${target.cadenceMinutes}m | enabled=${target.enabled}\n`,
    );
  }
}

async function approveTask(flags: Record<string, string>, positionals: string[]): Promise<void> {
  const idValue = positionals[0] ?? flags.id;
  if (!idValue) {
    throw new Error("Usage: sofia:approve-task <taskId>");
  }
  await markSofiaAgentTaskApproved(Number(idValue));
  process.stdout.write(`Approved Sofia task #${Number(idValue)}\n`);
}

async function sendApproved(config: ReturnType<typeof loadSofiaAgentConfig>): Promise<void> {
  const sentCount = await sendApprovedSofiaTasks(config, 20);
  process.stdout.write(`Sent ${sentCount} approved Sofia task(s)\n`);
}

async function sessionCheck(config: ReturnType<typeof loadSofiaAgentConfig>): Promise<void> {
  const self = await getSofiaSelf(config);
  process.stdout.write(
    `MTProto OK: id=${self.id} username=${self.username ?? "n/a"} name=${[self.firstName, self.lastName].filter(Boolean).join(" ") || "n/a"}\n`,
  );
}

async function listDialogs(config: ReturnType<typeof loadSofiaAgentConfig>): Promise<void> {
  const dialogs = await listPrivateDialogs(config, 20);
  if (dialogs.length === 0) {
    process.stdout.write("No private dialogs found\n");
    return;
  }
  for (const dialog of dialogs) {
    process.stdout.write(
      `${dialog.entityType} | ${dialog.title} | ${dialog.username ? `@${dialog.username}` : "no_username"} | ${dialog.peerKey}\n`,
    );
  }
}

async function main(): Promise<void> {
  const config = loadSofiaAgentConfig();
  initDb(config.databaseUrl);
  await ensureSchema();

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
    await startSofiaScheduler(config);
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

  process.stdout.write(
    [
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
    ].join("\n") + "\n",
  );
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
  process.exitCode = 1;
});
