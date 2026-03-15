import type { SofiaAgentConfig } from "../config";
import {
  createSofiaAgentTask,
  findSofiaTaskByDedupKey,
  listDueSofiaSearchTargets,
  markSofiaSearchTargetChecked,
} from "../db";
import { searchTelegramMessages } from "./mtproto";
import { ingestSofiaInbox } from "./inbox";
import { runSofiaGenerationBatch, sendApprovedSofiaTasks } from "./runtime";

function outreachTaskType(targetChat: string | null): "channel_comment" | "group_outreach" {
  return targetChat ? "channel_comment" : "group_outreach";
}

export async function runSofiaSearchSchedulerOnce(config: SofiaAgentConfig): Promise<{
  searchedTargets: number;
  tasksCreated: number;
}> {
  const dueTargets = await listDueSofiaSearchTargets();
  let tasksCreated = 0;

  for (const target of dueTargets) {
    const matches = await searchTelegramMessages(config, {
      query: target.query,
      targetChat: target.targetChat,
      limit: config.schedulerSearchLimit,
    });

    for (const match of matches) {
      if (match.outgoing) {
        continue;
      }
      const dedupKey = `search:${target.id}:${match.peerKey}:${match.id}`;
      const existing = await findSofiaTaskByDedupKey(dedupKey);
      if (existing) {
        continue;
      }

      await createSofiaAgentTask({
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

    await markSofiaSearchTargetChecked(target.id);
  }

  return {
    searchedTargets: dueTargets.length,
    tasksCreated,
  };
}

export async function runSofiaSchedulerCycle(config: SofiaAgentConfig): Promise<{
  inboxTasksCreated: number;
  outreachTasksCreated: number;
  draftsCreated: number;
  sentCount: number;
}> {
  const inbox = await ingestSofiaInbox(config);
  const discovery = await runSofiaSearchSchedulerOnce(config);
  const draftsCreated = await runSofiaGenerationBatch(config, config.generationBatchSize);
  const sentCount = config.autoSendApproved ? await sendApprovedSofiaTasks(config, config.generationBatchSize) : 0;

  return {
    inboxTasksCreated: inbox.tasksCreated,
    outreachTasksCreated: discovery.tasksCreated,
    draftsCreated,
    sentCount,
  };
}

export async function startSofiaScheduler(config: SofiaAgentConfig): Promise<void> {
  const intervalMs = Math.max(1, config.schedulerPollMinutes) * 60 * 1000;
  const runCycle = async (): Promise<void> => {
    const result = await runSofiaSchedulerCycle(config);
    process.stdout.write(
      [
        `[${new Date().toISOString()}] Sofia scheduler cycle`,
        `  inbox_tasks=${result.inboxTasksCreated}`,
        `  outreach_tasks=${result.outreachTasksCreated}`,
        `  drafts=${result.draftsCreated}`,
        `  sent=${result.sentCount}`,
      ].join("\n") + "\n",
    );
  };

  await runCycle();
  setInterval(() => {
    void runCycle().catch((error) => {
      process.stderr.write(
        `[${new Date().toISOString()}] Sofia scheduler failed: ${error instanceof Error ? error.stack ?? error.message : String(error)}\n`,
      );
    });
  }, intervalMs);
}
