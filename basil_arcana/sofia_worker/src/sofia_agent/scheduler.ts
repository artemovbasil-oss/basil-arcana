import type { SofiaAgentConfig } from "../config";
import {
  createSofiaSearchTarget,
  createSofiaAgentTask,
  findSofiaTaskByDedupKey,
  getLatestDraftForTask,
  getSofiaRuntimeState,
  listRecentInboundSofiaMessages,
  listSentSofiaOutreachSince,
  listSofiaAgentTasksByStatus,
  listSofiaSearchTargets,
  listDueSofiaSearchTargets,
  markSofiaAgentTaskApproved,
  markSofiaAgentTaskFailed,
  markSofiaSearchTargetChecked,
  resetSofiaSearchTarget,
  setSofiaRuntimeState,
  setSofiaSearchTargetEnabled,
} from "../db";
import { fetchTelegramMessageWindow, fetchTelegramMessageWindowWithClient, resolveCommunityTarget, resolveCommunityTargetWithClient, searchTelegramMessages, searchTelegramMessagesWithClient, sendTelegramText, type SofiaResolvedCommunityTarget, withSofiaTelegramClient } from "./mtproto";
import { fetchTgstatCommunityCandidates } from "./tgstat";
import { ingestSofiaInbox } from "./inbox";
import { runSofiaGenerationBatch, sendApprovedSofiaTasks } from "./runtime";

const MANUAL_SOCIAL_COMMUNITIES = [
  "https://t.me/russiansin_izmir",
  "https://t.me/russiansinturkey_stambul",
  "https://t.me/russiansin_georgia",
  "https://t.me/relocation_kaz",
  "https://t.me/russkie_v_gruzii",
  "https://t.me/russiansinturkey_antalya",
  "https://t.me/mybaku_chat",
  "https://t.me/Baku_Go_Chat",
  "https://t.me/ruskievstambule",
] as const;

const RELOCATION_DISCOVERY_QUERIES = [
  "русские стамбул",
  "русские в стамбуле",
  "русские турция чат",
  "релокация турция",
  "русские грузия чат",
  "релокация грузия",
  "русские баку чат",
  "релокация баку",
  "expats istanbul chat",
  "relocation turkey chat",
] as const;

function outreachTaskType(targetChat: string | null): "channel_comment" | "group_outreach" {
  return targetChat ? "channel_comment" : "group_outreach";
}

function isCommunityTask(taskType: string): boolean {
  return taskType === "channel_comment" || taskType === "group_outreach";
}

type SofiaOwnedPostKind =
  | "morning_ritual"
  | "daily_tarot_thought"
  | "daily_astro_forecast"
  | "daily_pop_culture"
  | "life_note";

interface CommunityCandidate {
  id: number;
  targetChat: string;
  label: string;
  sampleText: string;
  samplePermalink: string | null;
  query: string;
  writeMode: "group" | "discussion";
}

interface RelocationCandidate {
  targetChat: string;
  label: string;
  sampleText: string;
  samplePermalink: string | null;
  writeMode: "group" | "discussion";
  query: string;
}

async function ensureDefaultCommunityTargets(config: SofiaAgentConfig): Promise<void> {
  const existing = await listSofiaSearchTargets(false);
  const existingLabels = new Set(existing.map((target) => target.label));
  const defaults = [
    { label: "Global Tarot", query: "таро", cadenceMinutes: 15 },
    { label: "Global Tarot Spread", query: "расклад таро", cadenceMinutes: 20 },
    { label: "Global Divination", query: "гадание", cadenceMinutes: 20 },
    { label: "Global Horoscope", query: "гороскоп", cadenceMinutes: 25 },
    { label: "Global Zodiac", query: "знаки зодиака", cadenceMinutes: 25 },
    { label: "Global Tarot EN", query: "tarot", cadenceMinutes: 30 },
    { label: "Global Astrology", query: "астрология", cadenceMinutes: 25 },
    { label: "Global Astro Forecast", query: "астропрогноз", cadenceMinutes: 25 },
    { label: "Global Natal Chart", query: "натальная карта", cadenceMinutes: 30 },
    { label: "Global Horoscope EN", query: "horoscope", cadenceMinutes: 30 },
    { label: "Global Astrology EN", query: "astrology", cadenceMinutes: 30 },
    { label: "Ostorozhno News Feed", query: "", targetChat: "@ostorozhno_novosti", cadenceMinutes: 30 },
  ];
  if (config.ownedDiscussionChat) {
    defaults.push({
      label: "Estar Tarot Discussion",
      query: "",
      targetChat: config.ownedDiscussionChat,
      cadenceMinutes: 15,
    });
  }
  for (const target of defaults) {
    if (existingLabels.has(target.label)) {
      continue;
    }
    await createSofiaSearchTarget({
      label: target.label,
      query: target.query,
      targetChat: "targetChat" in target ? (target.targetChat ?? null) : null,
      cadenceMinutes: target.cadenceMinutes,
      metadata: {
        softCommunityDefault: true,
        mode: target.targetChat ? "active" : "discovery",
      },
    });
  }
}

async function ensureManualCommunityTargets(config: SofiaAgentConfig): Promise<void> {
  if (!config.communityModeEnabled) {
    return;
  }
  const existing = await listSofiaSearchTargets(false);
  const existingByHandle = new Map(
    existing
      .map((target) => [normalizeHandle(target.targetChat), target] as const)
      .filter((entry): entry is readonly [string, (typeof existing)[number]] => Boolean(entry[0])),
  );
  for (const target of existing) {
    if (target.metadata?.source !== "manual_allowlist") {
      continue;
    }
    const category = typeof target.metadata?.category === "string" ? target.metadata.category : "";
    if (category !== "social" && target.enabled) {
      await setSofiaSearchTargetEnabled(target.id, false, {
        disabledReason: "social_only_mode",
        disabledAt: new Date().toISOString(),
      });
    }
  }

  const manualTargets = MANUAL_SOCIAL_COMMUNITIES.map((url) => ({ url, category: "social" as const }));
  const manualHandles = new Set(
    manualTargets
      .map((item) => extractTelegramHandleFromUrl(item.url))
      .filter((value): value is string => Boolean(value)),
  );

  for (const target of existing) {
    if (target.metadata?.source !== "manual_allowlist") {
      continue;
    }
    const handle = normalizeHandle(target.targetChat);
    if (!handle || manualHandles.has(handle)) {
      continue;
    }
    await setSofiaSearchTargetEnabled(target.id, false, {
      disabledReason: "removed_from_manual_allowlist",
      disabledAt: new Date().toISOString(),
    });
  }

  for (const item of manualTargets) {
    if (isInviteOnlyTelegramUrl(item.url)) {
      console.info(`[${new Date().toISOString()}] manual community target skipped (invite-only): ${item.url}`);
      continue;
    }
    const handle = extractTelegramHandleFromUrl(item.url);
    if (!handle) {
      continue;
    }
    const existingTarget = existingByHandle.get(handle);
    if (existingTarget) {
      const disabledReason =
        typeof existingTarget.metadata?.disabledReason === "string"
          ? existingTarget.metadata.disabledReason
          : null;
      const shouldKeepDisabled = disabledReason === "access_lost";
      if (shouldKeepDisabled) {
        await resetSofiaSearchTarget(existingTarget.id, false, {
          source: "manual_allowlist",
          category: item.category,
          workflow: "review_first",
          noPromoToday: true,
        });
        continue;
      }
      await resetSofiaSearchTarget(existingTarget.id, true, {
        source: "manual_allowlist",
        category: item.category,
        workflow: "review_first",
        noPromoToday: true,
        disabledReason: null,
        disabledAt: null,
        resolveError: null,
        targetKind: null,
      });
      continue;
    }
    await createSofiaSearchTarget({
      label: `Manual ${item.category}: ${handle}`,
      query: "",
      targetChat: handle,
      cadenceMinutes: item.category === "social" ? 10 : 20,
      metadata: {
        mode: "active",
        source: "manual_allowlist",
        category: item.category,
        workflow: "review_first",
        noPromoToday: true,
      },
    });
  }
}

function currentHourBucket(now: Date): string {
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-${String(now.getUTCDate()).padStart(2, "0")}T${String(now.getUTCHours()).padStart(2, "0")}:00Z`;
}

function trimSourceText(text: string | null): string | null {
  if (!text) {
    return null;
  }
  const normalized = text.replace(/\s+/g, " ").trim();
  if (!normalized) {
    return null;
  }
  return normalized.length > 120 ? `${normalized.slice(0, 117)}...` : normalized;
}

function normalizeHandle(value: string | null | undefined): string | null {
  if (!value) {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.startsWith("@") ? trimmed.toLowerCase() : `@${trimmed.toLowerCase()}`;
}

function extractTelegramHandleFromUrl(url: string | null | undefined): string | null {
  if (!url) {
    return null;
  }
  const match = url.match(/t\.me\/([A-Za-z0-9_]+)/i);
  return match ? normalizeHandle(match[1]) : null;
}

function isInviteOnlyTelegramUrl(url: string): boolean {
  return /t\.me\/\+/i.test(url);
}

function isCommunityAccessLossError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return /CHANNEL_PRIVATE|CHAT_ADMIN_REQUIRED|CHAT_FORBIDDEN|CHANNEL_INVALID|USER_BANNED_IN_CHANNEL|PEER_ID_INVALID/i.test(
    message,
  );
}

function buildDiscoveryExclusionHandles(config: SofiaAgentConfig, approverHandle: string | null): Set<string> {
  const handles = new Set<string>();
  const add = (value: string | null | undefined): void => {
    const normalized = normalizeHandle(value);
    if (normalized) {
      handles.add(normalized);
    }
  };
  add(config.personaHandle);
  add(config.ownedChannelHandle);
  add(config.ownedDiscussionChat);
  add(approverHandle);
  add("@ostorozhno_novosti");
  add("@tarot_arkana_bot");
  add(extractTelegramHandleFromUrl(config.recommendBotUrl));
  return handles;
}

function candidateStateKey(): string {
  return "community_candidate_approval";
}

function communityDraftApprovalStateKey(): string {
  return "community_draft_approval";
}

function communityPriority(target: { metadata?: Record<string, unknown> | null }): number {
  const category = typeof target.metadata?.category === "string" ? target.metadata.category : "";
  if (category === "social") {
    return 0;
  }
  if (category === "esoterics") {
    return 1;
  }
  if (category === "psychology") {
    return 2;
  }
  return 3;
}

function isSocialCategory(target: { metadata?: Record<string, unknown> | null }): boolean {
  return target.metadata?.category === "social";
}

function socialHandleSet(): Set<string> {
  return new Set(
    MANUAL_SOCIAL_COMMUNITIES.map((url) => extractTelegramHandleFromUrl(url)).filter(
      (value): value is string => Boolean(value),
    ),
  );
}

function socialRhythmMode(now: number): "pause" | "normal" | "active" {
  const twoHourBucket = Math.floor(now / (2 * 60 * 60 * 1000));
  const remainder = twoHourBucket % 7;
  if (remainder === 0) {
    return "pause";
  }
  if (remainder === 1 || remainder === 2) {
    return "active";
  }
  return "normal";
}

function isCommunityDraftApproveCommand(text: string): boolean {
  const normalized = text.trim().toLowerCase();
  return normalized === "ok" || normalized === "send" || normalized === "approve";
}

function isCommunityDraftCancelCommand(text: string): boolean {
  const normalized = text.trim().toLowerCase();
  return normalized === "cancel" || normalized === "skip" || normalized === "reject";
}

function isRejectMessage(text: string): boolean {
  const normalized = text.toLowerCase();
  return (
    normalized.includes("ищи другие") ||
    normalized.includes("search others") ||
    normalized.includes("find others") ||
    normalized.includes("reject all") ||
    normalized === "reject" ||
    normalized === "cancel"
  );
}

function extractApprovalIds(text: string, maxId: number): number[] {
  const normalized = text.toLowerCase();
  if (normalized.includes("all") || normalized.includes("все")) {
    return Array.from({ length: maxId }, (_, index) => index + 1);
  }
  const matches = normalized.match(/\d+/g) ?? [];
  return matches
    .map((value) => Number(value))
    .filter((value) => Number.isFinite(value) && value >= 1 && value <= maxId);
}

function buildCandidateApprovalMessage(candidates: CommunityCandidate[]): string {
  const lines = [
    "Нашла новые сообщества/каналы по таро и астрологии. Ниже короткий шортлист.",
    "",
  ];
  for (const candidate of candidates) {
    const excerpt = trimSourceText(candidate.sampleText) ?? "без примера текста";
    const link = candidate.samplePermalink ? `\n${candidate.samplePermalink}` : "";
    const modeLabel = candidate.writeMode === "discussion" ? "комментарии открыты" : "можно писать в группе";
    lines.push(`${candidate.id}. ${candidate.label} (${modeLabel}) — ${excerpt}${link}`);
  }
  lines.push("");
  lines.push("Если ок, ответь: approve 1,2 или все.");
  lines.push("Если не ок, ответь: ищи другие.");
  return lines.join("\n");
}

function buildRelocationSuggestionMessage(candidates: RelocationCandidate[]): string {
  const lines = [
    "Нашла новые релокационные чаты, куда можно вступить вручную и потом дать мне работать там.",
    "",
  ];
  candidates.forEach((candidate, index) => {
    const excerpt = trimSourceText(candidate.sampleText) ?? "без примера текста";
    const link = candidate.samplePermalink ? `\n${candidate.samplePermalink}` : "";
    const modeLabel = candidate.writeMode === "discussion" ? "через комментарии" : "обычная группа";
    lines.push(`${index + 1}. ${candidate.label} — ${candidate.targetChat} (${modeLabel}) — ${excerpt}${link}`);
  });
  lines.push("");
  lines.push("Если вступишь в какой-то из них, просто пришли мне хэндл, и я добавлю его в рабочие social-чаты.");
  return lines.join("\n");
}

function buildCommunityDraftApprovalMessage(input: {
  taskId: number;
  targetChat: string;
  sourceChannel: string | null;
  sourceText: string | null;
  sourcePermalink: string | null;
  draftText: string;
}): string {
  const lines = [
    "План действия по сообществу. Сейчас показываю один draft на аппрув.",
    "",
    `Task: ${input.taskId}`,
    `Куда: ${input.targetChat}`,
    `Источник: ${input.sourceChannel ?? "сообщество"}`,
  ];
  if (input.sourceText) {
    lines.push(`Сообщение пользователя: ${trimSourceText(input.sourceText) ?? input.sourceText}`);
  }
  if (input.sourcePermalink) {
    lines.push(`Ссылка: ${input.sourcePermalink}`);
  }
  lines.push("");
  lines.push("Черновик:");
  lines.push(input.draftText);
  lines.push("");
  lines.push("Если ок, ответь: ok");
  lines.push("Если пропускаем, ответь: cancel");
  return lines.join("\n");
}

async function maybeProcessCommunityApprovals(config: SofiaAgentConfig): Promise<void> {
  const approverHandle = normalizeHandle(config.outreachReportChat);
  if (!approverHandle) {
    return;
  }
  const pending = await getSofiaRuntimeState(candidateStateKey());
  const items = Array.isArray(pending?.items) ? (pending?.items as CommunityCandidate[]) : [];
  if (!items.length) {
    return;
  }

  const processedIds = new Set(
    Array.isArray(pending?.processedMessageIds)
      ? (pending?.processedMessageIds as unknown[]).map((value) => String(value))
      : [],
  );
  const inbound = await listRecentInboundSofiaMessages(50);
  const approverMessages = inbound.filter((message) => {
    const metadata = message.metadata ?? {};
    return normalizeHandle(typeof metadata.chatUsername === "string" ? metadata.chatUsername : null) === approverHandle;
  });
  if (!approverMessages.length) {
    return;
  }

  const existingTargets = await listSofiaSearchTargets(false);
  for (const message of approverMessages) {
    const platformMessageId = String(message.platformMessageId);
    if (processedIds.has(platformMessageId)) {
      continue;
    }
    processedIds.add(platformMessageId);
    const text = message.messageText.trim();
    if (!text) {
      continue;
    }

    if (isRejectMessage(text)) {
      console.info(`[${new Date().toISOString()}] community shortlist rejected by ${approverHandle}`);
      await sendTelegramText(config, {
        targetChat: approverHandle,
        message: "Ок, этот шортлист отклоняю и ищу другие сообщества.",
      });
      await setSofiaRuntimeState(candidateStateKey(), {
        items: [],
        processedMessageIds: Array.from(processedIds),
        lastDecision: "rejected",
        updatedAt: new Date().toISOString(),
      });
      return;
    }

    const approvedIds = extractApprovalIds(text, items.length);
    if (!approvedIds.length) {
      continue;
    }
    console.info(
      `[${new Date().toISOString()}] community shortlist approved by ${approverHandle}: ids=${approvedIds.join(",")}`,
    );
    const existingChats = new Set(existingTargets.map((target) => normalizeHandle(target.targetChat)).filter(Boolean));
    const activatedLabels: string[] = [];
    for (const approvedId of approvedIds) {
      const candidate = items.find((item) => item.id === approvedId);
      if (!candidate) {
        continue;
      }
      const normalizedTarget = normalizeHandle(candidate.targetChat);
      const existingTarget = normalizedTarget
        ? existingTargets.find((target) => normalizeHandle(target.targetChat) === normalizedTarget)
        : null;
      if (existingTarget) {
        if (!existingTarget.enabled) {
          await setSofiaSearchTargetEnabled(existingTarget.id, true, {
            approvedBy: approverHandle,
            approvedAt: new Date().toISOString(),
            source: "community_discovery_reactivated",
            samplePermalink: candidate.samplePermalink,
          });
          activatedLabels.push(candidate.label);
        }
        continue;
      }
      await createSofiaSearchTarget({
        label: `Approved Community: ${candidate.label}`,
        query: "",
        targetChat: candidate.targetChat,
        cadenceMinutes: 15,
        metadata: {
          approvedBy: approverHandle,
          approvedAt: new Date().toISOString(),
          source: "community_discovery",
          samplePermalink: candidate.samplePermalink,
        },
      });
      if (normalizedTarget) {
        existingChats.add(normalizedTarget);
      }
      activatedLabels.push(candidate.label);
    }
    await sendTelegramText(config, {
      targetChat: approverHandle,
      message: activatedLabels.length
        ? `Принято. Активировала сообщества: ${activatedLabels.join(", ")}. Дальше буду там работать сама.`
        : "Похоже, эти пункты уже были активированы раньше или стали неактуальны. Могу прислать новый шортлист.",
    });
    await setSofiaRuntimeState(candidateStateKey(), {
      items: [],
      processedMessageIds: Array.from(processedIds),
      lastDecision: "approved",
      updatedAt: new Date().toISOString(),
    });
    return;
  }
}

async function maybeProcessCommunityDraftApprovals(config: SofiaAgentConfig): Promise<void> {
  const approverHandle = normalizeHandle(config.outreachReportChat);
  if (!approverHandle) {
    return;
  }
  const state = (await getSofiaRuntimeState(communityDraftApprovalStateKey())) ?? {};
  const currentTaskId =
    typeof state.taskId === "number"
      ? state.taskId
      : typeof state.taskId === "string"
        ? Number(state.taskId)
        : null;
  if (!Number.isFinite(currentTaskId)) {
    return;
  }
  const taskId = Number(currentTaskId);

  const processedIds = new Set(
    Array.isArray(state.processedMessageIds)
      ? state.processedMessageIds.map((value) => String(value))
      : [],
  );
  const inbound = await listRecentInboundSofiaMessages(50);
  const approverMessages = inbound.filter((message) => {
    const metadata = message.metadata ?? {};
    return normalizeHandle(typeof metadata.chatUsername === "string" ? metadata.chatUsername : null) === approverHandle;
  });

  for (const message of approverMessages) {
    const platformMessageId = String(message.platformMessageId);
    if (processedIds.has(platformMessageId)) {
      continue;
    }
    processedIds.add(platformMessageId);
    const text = message.messageText.trim();
    if (!text) {
      continue;
    }

    if (isCommunityDraftApproveCommand(text)) {
      await markSofiaAgentTaskApproved(taskId);
      await setSofiaRuntimeState(communityDraftApprovalStateKey(), {
        taskId: null,
        processedMessageIds: Array.from(processedIds),
        lastDecision: "approved",
        updatedAt: new Date().toISOString(),
      });
      await sendTelegramText(config, {
        targetChat: approverHandle,
        message: `Принято. Отправляю task ${taskId}.`,
      });
      console.info(`[${new Date().toISOString()}] community draft approved by ${approverHandle}: task=${taskId}`);
      return;
    }

    if (isCommunityDraftCancelCommand(text)) {
      await markSofiaAgentTaskFailed(taskId, "Cancelled by approver");
      await setSofiaRuntimeState(communityDraftApprovalStateKey(), {
        taskId: null,
        processedMessageIds: Array.from(processedIds),
        lastDecision: "cancelled",
        updatedAt: new Date().toISOString(),
      });
      await sendTelegramText(config, {
        targetChat: approverHandle,
        message: `Ок, task ${taskId} пропускаю. Подготовлю следующий draft.`,
      });
      console.info(`[${new Date().toISOString()}] community draft cancelled by ${approverHandle}: task=${taskId}`);
      return;
    }
  }
}

async function maybeRequestCommunityDraftApproval(config: SofiaAgentConfig): Promise<void> {
  const approverHandle = normalizeHandle(config.outreachReportChat);
  if (!approverHandle) {
    return;
  }
  const state = (await getSofiaRuntimeState(communityDraftApprovalStateKey())) ?? {};
  const existingTaskId =
    typeof state.taskId === "number"
      ? state.taskId
      : typeof state.taskId === "string"
        ? Number(state.taskId)
        : null;
  if (Number.isFinite(existingTaskId)) {
    return;
  }

  const draftReadyTasks = await listSofiaAgentTasksByStatus("draft_ready", 50);
  const nextTask = draftReadyTasks.find((task) => isCommunityTask(task.taskType) && Boolean(task.targetChat));
  if (!nextTask || !nextTask.targetChat) {
    return;
  }
  const draft = await getLatestDraftForTask(nextTask.id);
  if (!draft) {
    return;
  }
  const payload = nextTask.payload ?? {};
  await sendTelegramText(config, {
    targetChat: approverHandle,
    message: buildCommunityDraftApprovalMessage({
      taskId: nextTask.id,
      targetChat: nextTask.targetChat,
      sourceChannel: nextTask.sourceChannel,
      sourceText: typeof payload.sourceText === "string" ? payload.sourceText : null,
      sourcePermalink: typeof payload.sourcePermalink === "string" ? payload.sourcePermalink : null,
      draftText: draft.draftText,
    }),
  });
  await setSofiaRuntimeState(communityDraftApprovalStateKey(), {
    taskId: nextTask.id,
    processedMessageIds: [],
    requestedAt: new Date().toISOString(),
  });
  console.info(`[${new Date().toISOString()}] community draft queued for approval: task=${nextTask.id}`);
}

async function maybeDiscoverCommunityCandidates(config: SofiaAgentConfig): Promise<void> {
  const approverHandle = normalizeHandle(config.outreachReportChat);
  if (!config.communityModeEnabled || !approverHandle) {
    return;
  }
  const pending = await getSofiaRuntimeState(candidateStateKey());
  const existingPending = Array.isArray(pending?.items) ? pending.items : [];
  if (existingPending.length) {
    console.info(
      `[${new Date().toISOString()}] community shortlist pending approval: count=${existingPending.length}`,
    );
    return;
  }

  const targets = await listSofiaSearchTargets(true);
  const discoveryTargets = targets.filter(
    (target) => target.targetChat === null && ((target.metadata?.mode as string | undefined) ?? "") === "discovery",
  );
  if (!discoveryTargets.length) {
    return;
  }

  const approvedChats = new Set(
    targets
      .filter((target) => target.targetChat)
      .map((target) => normalizeHandle(target.targetChat))
      .filter(Boolean),
  );
  const excludedHandles = buildDiscoveryExclusionHandles(config, approverHandle);
  for (const handle of excludedHandles) {
    approvedChats.add(handle);
  }

  const candidates = new Map<string, CommunityCandidate>();
  for (const target of discoveryTargets) {
    const matches = await searchTelegramMessages(config, {
      query: target.query,
      limit: Math.max(10, Math.min(config.schedulerSearchLimit * 2, 20)),
    });
    console.info(
      `[${new Date().toISOString()}] discovery target checked: label=${target.label} query="${target.query}" matches=${matches.length}`,
    );
    for (const match of matches) {
      const normalizedTarget = normalizeHandle(match.chatUsername ? `@${match.chatUsername}` : null);
      if (!normalizedTarget || approvedChats.has(normalizedTarget) || candidates.has(normalizedTarget)) {
        continue;
      }
      const textLower = match.text.toLowerCase();
      if (
        textLower.includes("tarot_arkana_bot") ||
        textLower.includes("sofiaknoxx") ||
        textLower.includes("estartarot") ||
        textLower.includes("uxd_ink")
      ) {
        continue;
      }
      if (!match.chatTitle || !match.text) {
        continue;
      }
      const resolvedCandidate = await resolveCommunityTarget(config, normalizedTarget);
      if (!resolvedCandidate.isWritableCommunity) {
        continue;
      }
      candidates.set(normalizedTarget, {
        id: candidates.size + 1,
        targetChat: normalizedTarget,
        label: match.chatTitle,
        sampleText: match.text,
        samplePermalink: match.permalink,
        query: target.query,
        writeMode: resolvedCandidate.usedLinkedDiscussion ? "discussion" : "group",
      });
      if (candidates.size >= 5) {
        break;
      }
    }
    await markSofiaSearchTargetChecked(target.id);
    if (candidates.size >= 5) {
      break;
    }
  }

  if (!candidates.size) {
    console.info(`[${new Date().toISOString()}] community candidates found=0`);
    return;
  }

  const items = Array.from(candidates.values());
  console.info(`[${new Date().toISOString()}] community candidates found=${items.length}`);
  await sendTelegramText(config, {
    targetChat: approverHandle,
    message: buildCandidateApprovalMessage(items),
  });
  console.info(
    `[${new Date().toISOString()}] community shortlist sent to ${approverHandle}: count=${items.length}`,
  );
  await setSofiaRuntimeState(candidateStateKey(), {
    items,
    processedMessageIds: [],
    lastSentAt: new Date().toISOString(),
  });
}

async function maybeSuggestRelocationCommunities(config: SofiaAgentConfig): Promise<void> {
  const approverHandle = normalizeHandle(config.outreachReportChat);
  if (!approverHandle || !config.communityModeEnabled) {
    return;
  }
  const stateKey = "relocation_discovery_shortlist";
  const state = (await getSofiaRuntimeState(stateKey)) ?? {};
  const lastSentAt =
    typeof state.lastSentAt === "string" ? Date.parse(state.lastSentAt) : 0;
  const now = Date.now();
  if (Number.isFinite(lastSentAt) && now - lastSentAt < 12 * 60 * 60 * 1000) {
    return;
  }

  const existingTargets = await listSofiaSearchTargets(false);
  const excludedHandles = new Set(
    existingTargets
      .map((target) => normalizeHandle(target.targetChat))
      .filter((value): value is string => Boolean(value)),
  );
  for (const handle of buildDiscoveryExclusionHandles(config, approverHandle)) {
    excludedHandles.add(handle);
  }

  const candidates = new Map<string, RelocationCandidate>();
  for (const query of RELOCATION_DISCOVERY_QUERIES) {
    const matches = await searchTelegramMessages(config, {
      query,
      limit: Math.max(10, Math.min(config.schedulerSearchLimit * 2, 20)),
    });
    for (const match of matches) {
      const normalizedTarget = normalizeHandle(match.chatUsername ? `@${match.chatUsername}` : null);
      if (!normalizedTarget || excludedHandles.has(normalizedTarget) || candidates.has(normalizedTarget)) {
        continue;
      }
      if (!match.chatTitle || !isMeaningfulCommunityText(match.text)) {
        continue;
      }
      let resolvedCandidate: SofiaResolvedCommunityTarget;
      try {
        resolvedCandidate = await resolveCommunityTarget(config, normalizedTarget);
      } catch {
        continue;
      }
      if (!resolvedCandidate.isWritableCommunity) {
        continue;
      }
      candidates.set(normalizedTarget, {
        targetChat: normalizedTarget,
        label: match.chatTitle,
        sampleText: match.text,
        samplePermalink: match.permalink,
        query,
        writeMode: resolvedCandidate.usedLinkedDiscussion ? "discussion" : "group",
      });
      if (candidates.size >= 7) {
        break;
      }
    }
    if (candidates.size >= 7) {
      break;
    }
  }

  if (!candidates.size) {
    return;
  }

  const items = Array.from(candidates.values());
  await sendTelegramText(config, {
    targetChat: approverHandle,
    message: buildRelocationSuggestionMessage(items),
  });
  await setSofiaRuntimeState(stateKey, {
    lastSentAt: new Date(now).toISOString(),
    items,
  });
  console.info(`[${new Date().toISOString()}] relocation shortlist sent to ${approverHandle}: count=${items.length}`);
}


async function syncTgstatCommunityTargets(config: SofiaAgentConfig): Promise<void> {
  if (!config.tgstatSyncEnabled || !config.tgstatApiToken) {
    return;
  }
  const existingTargets = await listSofiaSearchTargets(false);
  const byHandle = new Map(existingTargets.map((target) => [normalizeHandle(target.targetChat), target]));
  const candidates = await fetchTgstatCommunityCandidates(config);
  let activated = 0;
  for (const candidate of candidates) {
    const existing = byHandle.get(normalizeHandle(candidate.targetChat));
    if (existing) {
      if (!existing.enabled) {
        await setSofiaSearchTargetEnabled(existing.id, true, {
          source: 'tgstat_api_reactivated',
          category: candidate.category,
          sourceUsername: candidate.sourceUsername,
        });
        activated += 1;
      }
      continue;
    }
    await createSofiaSearchTarget({
      label: `TGStat ${candidate.category}: ${candidate.title}`,
      query: '',
      targetChat: candidate.targetChat,
      cadenceMinutes: 15,
      metadata: {
        mode: 'active',
        source: 'tgstat_api',
        category: candidate.category,
        sourceUsername: candidate.sourceUsername,
        sourceLink: candidate.link,
      },
    });
    activated += 1;
  }
  if (activated > 0) {
    console.info(`[${new Date().toISOString()}] tgstat targets activated=${activated}`);
  }
}

function isLikelyCommunityQuestionText(text: string): boolean {
  const normalized = text.trim().toLowerCase();
  if (!normalized) return false;
  if (normalized.includes('?')) return true;
  return /^(как|что|кто|где|когда|почему|зачем|можно|нужно|стоит|подскажите|скажите|посоветуйте)/u.test(normalized);
}

function isMeaningfulCommunityText(text: string): boolean {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (!normalized) {
    return false;
  }
  if (normalized.length < 18) {
    return false;
  }
  const lower = normalized.toLowerCase();
  if (
    lower === "спасибо" ||
    lower === "благодарю" ||
    lower === "да" ||
    lower === "нет" ||
    lower === "ок"
  ) {
    return false;
  }
  return true;
}

function isLikelyBroadcastOrAdminPost(match: { chatTitle: string | null; senderLabel: string | null; text: string }): boolean {
  const chat = (match.chatTitle ?? '').trim().toLowerCase();
  const sender = (match.senderLabel ?? '').trim().toLowerCase();
  if (chat && sender && chat == sender) return true;
  const text = match.text.trim();
  return false;
}

function localHourParts(date: Date, timeZone: string): { dayKey: string; hour: number; minute: number } {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = formatter.formatToParts(date);
  const year = parts.find((part) => part.type === "year")?.value ?? "0000";
  const month = parts.find((part) => part.type === "month")?.value ?? "00";
  const day = parts.find((part) => part.type === "day")?.value ?? "00";
  const hour = Number(parts.find((part) => part.type === "hour")?.value ?? "0");
  const minute = Number(parts.find((part) => part.type === "minute")?.value ?? "0");
  return {
    dayKey: `${year}-${month}-${day}`,
    hour,
    minute,
  };
}

async function maybeScheduleOwnedChannelPosts(config: SofiaAgentConfig): Promise<number> {
  if (!config.ownedChannelEnabled || !config.ownedChannelHandle) {
    return 0;
  }
  const now = new Date();
  const { dayKey, hour, minute } = localHourParts(now, config.ownedChannelTimezone);
  const stateKey = "owned_channel_post_schedule";
  const state = (await getSofiaRuntimeState(stateKey)) ?? {};
  const done = new Set(Array.isArray(state.done) ? state.done.map((item) => String(item)) : []);

  const candidates: Array<{ kind: SofiaOwnedPostKind; hour: number; minute: number; title: string; notes: string }> = [
    {
      kind: "morning_ritual",
      hour: 7,
      minute: 17,
      title: "Morning greeting ritual",
      notes:
        "Write the post in Russian for @estartarot. This is Sofia's daily morning greeting for the channel. The structure must include exactly these four elements in a polished Telegram-native flow: 1) карта дня, 2) астропрогноз по общему планетарному фону на день, 3) сильная женская мотивирующая цитата, 4) короткая утренняя аффирмация. Make it warm, feminine, elegant, and readable. No filler, no politics, no negativity. The quote should feel memorable and empowering.",
    },
    {
      kind: "daily_astro_forecast",
      hour: 9,
      minute: 0,
      title: "Daily astro forecast",
      notes: "Author a concise daily astrological forecast for the channel. Make it feel original, practical, and atmospheric. No hard factual claims about external news.",
    },
    {
      kind: "daily_tarot_thought",
      hour: 14,
      minute: 0,
      title: "Tarot thought of the day",
      notes: "Write an original tarot reflection for the channel as if Sofia is sharing a thoughtful insight from practice. Make it feel authored, not generic.",
    },
    {
      kind: "daily_pop_culture",
      hour: 20,
      minute: 0,
      title: "Pop culture and intuition note",
      notes:
        "Write the post in Russian. Use @ostorozhno_novosti as a source of light celebrity or lifestyle notes only. No politics, no crime, no tragedy, no negativity. Do not repost. Rewrite in Sofia's own words and add a short original astro/tarot angle.",
    },
  ];

  let created = 0;
  for (const candidate of candidates) {
    const bucket = `${dayKey}:${candidate.kind}`;
    if (hour !== candidate.hour || minute !== candidate.minute || done.has(bucket)) {
      continue;
    }
    await createSofiaAgentTask({
      taskType: "channel_post",
      title: candidate.title,
      sourceChannel: config.ownedChannelHandle,
      targetChat: config.ownedChannelHandle,
      payload: {
        dedupKey: `owned-channel:${bucket}`,
        postKind: candidate.kind,
        channelHandle: config.ownedChannelHandle,
        recommendBotUrl: config.recommendBotUrl,
        editorialNotes: candidate.notes,
        language: "ru",
      },
    });
    done.add(bucket);
    created += 1;
  }

  const lastLifeNoteMs = typeof state.lastLifeNoteAt === "number" ? state.lastLifeNoteAt : 0;
  const lifeNoteReady =
    hour === 18 &&
    minute === 0 &&
    now.getTime() - lastLifeNoteMs >= 36 * 60 * 60 * 1000 &&
    !done.has(`${dayKey}:life_note`);
  if (lifeNoteReady) {
    await createSofiaAgentTask({
      taskType: "channel_post",
      title: "Life note",
      sourceChannel: config.ownedChannelHandle,
      targetChat: config.ownedChannelHandle,
      payload: {
        dedupKey: `owned-channel:${dayKey}:life_note`,
        postKind: "life_note",
        channelHandle: config.ownedChannelHandle,
        recommendBotUrl: config.recommendBotUrl,
        editorialNotes:
          "Write a small personal-feeling channel note in Russian about travel, a recent purchase, a street detail, a cafe, a book, or another lived-in moment. Keep it warm and believable, but do not claim real-world facts that require verification.",
        language: "ru",
      },
    });
    done.add(`${dayKey}:life_note`);
    created += 1;
    await setSofiaRuntimeState(stateKey, {
      done: Array.from(done),
      lastLifeNoteAt: now.getTime(),
    });
    return created;
  }

  await setSofiaRuntimeState(stateKey, {
    done: Array.from(done),
    lastLifeNoteAt: lastLifeNoteMs,
  });
  return created;
}

function buildOutreachReportMessage(items: Awaited<ReturnType<typeof listSentSofiaOutreachSince>>): string {
  if (items.length === 0) {
    return "За последний час по outreach ничего не отправляла.";
  }
  const lines = [
    `За последний час по outreach отправила ${items.length} ${items.length === 1 ? "сообщение" : "сообщения"}.`,
  ];
  for (const item of items.slice(0, 8)) {
    const where = item.sourceChannel || item.targetChat || item.title;
    const excerpt = trimSourceText(item.sourceText);
    const linkSuffix = item.sourcePermalink ? `\n  ${item.sourcePermalink}` : "";
    lines.push(`- ${where}${excerpt ? ` — ${excerpt}` : ""}${linkSuffix}`);
  }
  return lines.join("\n");
}

async function maybeSendOutreachHourlyReport(config: SofiaAgentConfig): Promise<void> {
  if (!config.outreachReportEnabled || !config.outreachReportChat) {
    return;
  }
  const now = new Date();
  const bucket = currentHourBucket(now);
  const stateKey = "outreach_hourly_report";
  const state = await getSofiaRuntimeState(stateKey);
  if (state && state.lastBucket === bucket) {
    return;
  }
  const sinceMs = now.getTime() - 60 * 60 * 1000;
  const items = await listSentSofiaOutreachSince(sinceMs);
  const message = buildOutreachReportMessage(items);
  await sendTelegramText(config, {
    targetChat: config.outreachReportChat,
    message,
  });
  await setSofiaRuntimeState(stateKey, {
    lastBucket: bucket,
    sentAt: now.toISOString(),
    count: items.length,
  });
}

export async function runSofiaSearchSchedulerOnce(config: SofiaAgentConfig): Promise<{
  searchedTargets: number;
  tasksCreated: number;
}> {
  if (!config.communityModeEnabled) {
    return { searchedTargets: 0, tasksCreated: 0 };
  }
  await ensureManualCommunityTargets(config);
  const dueTargets = (await listDueSofiaSearchTargets()).sort((a, b) => {
    const priorityDelta = communityPriority(a) - communityPriority(b);
    if (priorityDelta !== 0) {
      return priorityDelta;
    }
    return a.id - b.id;
  });
  console.info(`[${new Date().toISOString()}] community due targets=${dueTargets.length}`);
  for (const dueTarget of dueTargets) {
    console.info(`[${new Date().toISOString()}] community due target: id=${dueTarget.id} label=${dueTarget.label} target=${dueTarget.targetChat ?? 'GLOBAL'} query="${dueTarget.query}"`);
  }
  let tasksCreated = 0;
  const now = Date.now();
  const freshWindowMs = config.communityFreshHours * 60 * 60 * 1000;
  const socialHandles = socialHandleSet();
  const socialRhythm = socialRhythmMode(now);
  const recentSocialOutreach = new Set(
    (await listSentSofiaOutreachSince(now - 30 * 60 * 1000))
      .map((item) => normalizeHandle(item.targetChat))
      .filter((value): value is string => Boolean(value)),
  );
  const sentSocialLastHour = (await listSentSofiaOutreachSince(now - 60 * 60 * 1000)).filter((item) => {
    const handle = normalizeHandle(item.targetChat);
    return handle ? socialHandles.has(handle) : false;
  }).length;
  const sentSocialLastTwoHours = (await listSentSofiaOutreachSince(now - 2 * 60 * 60 * 1000)).filter((item) => {
    const handle = normalizeHandle(item.targetChat);
    return handle ? socialHandles.has(handle) : false;
  }).length;
  const socialQueuedThisCycle = new Set<string>();

  for (const target of dueTargets) {
    const mode = (target.metadata?.mode as string | undefined) ?? (target.targetChat ? "active" : "discovery");
    const isSourceFeed = normalizeHandle(target.targetChat) === normalizeHandle("@ostorozhno_novosti");
    if (mode === "discovery" || isSourceFeed) {
      await markSofiaSearchTargetChecked(target.id);
      continue;
    }
    if (isSocialCategory(target)) {
      if (socialRhythm === "pause") {
        console.info(`[${new Date().toISOString()}] social rhythm pause: target=${target.targetChat ?? "GLOBAL"}`);
        await markSofiaSearchTargetChecked(target.id);
        continue;
      }
      if (socialRhythm === "normal" && sentSocialLastHour >= 2) {
        console.info(`[${new Date().toISOString()}] social rhythm cap hit (hour): target=${target.targetChat ?? "GLOBAL"}`);
        await markSofiaSearchTargetChecked(target.id);
        continue;
      }
      if (socialRhythm === "active" && sentSocialLastTwoHours >= 5) {
        console.info(`[${new Date().toISOString()}] social rhythm cap hit (2h): target=${target.targetChat ?? "GLOBAL"}`);
        await markSofiaSearchTargetChecked(target.id);
        continue;
      }
    }
    try {
      await withSofiaTelegramClient(config, async (client) => {
        const resolvedTarget = target.targetChat
          ? await resolveCommunityTargetWithClient(client, target.targetChat)
          : null;
        if (resolvedTarget && !resolvedTarget.isWritableCommunity) {
          console.info(
            `[${new Date().toISOString()}] community target skipped as non-writable: requested=${resolvedTarget.requestedTarget} kind=${resolvedTarget.targetKind}`,
          );
          await setSofiaSearchTargetEnabled(target.id, false, {
            disabledReason: "non_writable",
            disabledAt: new Date().toISOString(),
            targetKind: resolvedTarget.targetKind,
          });
          return;
        }
        if (resolvedTarget?.usedLinkedDiscussion) {
          console.info(
            `[${new Date().toISOString()}] community target rerouted to discussion: requested=${resolvedTarget.requestedTarget} effective=${resolvedTarget.effectiveTarget}`,
          );
        }
        console.info(`[${new Date().toISOString()}] community checking target: id=${target.id} requested=${target.targetChat ?? 'GLOBAL'} effective=${resolvedTarget?.effectiveTarget ?? target.targetChat ?? 'GLOBAL'} query="${target.query}"`);
        const matches = await searchTelegramMessagesWithClient(client, {
          query: target.query,
          targetChat: resolvedTarget?.effectiveTarget ?? target.targetChat,
          limit: config.schedulerSearchLimit,
        });

        const eligibleMatches = matches.filter((match) => {
      if (match.outgoing) return false;
      if (!match.chatTitle && !match.chatUsername) return false;
      const maxAgeMs = isSocialCategory(target) ? 36 * 60 * 60 * 1000 : freshWindowMs;
      if (now - match.sentAt > maxAgeMs) return false;
      const sender = (match.senderLabel ?? '').trim().toLowerCase();
      const chat = (match.chatTitle ?? '').trim().toLowerCase();
      if (sender && chat && sender === chat) return false;
      return isMeaningfulCommunityText(match.text);
        });
        const questionMatches = eligibleMatches.filter((match) => isLikelyCommunityQuestionText(match.text));
        const candidateMatches = (questionMatches.length ? questionMatches : eligibleMatches.slice(0, 1)).slice(
      0,
      isSocialCategory(target) ? 1 : questionMatches.length ? questionMatches.length : 1,
        );

        console.info(`[${new Date().toISOString()}] community matches found: target=${resolvedTarget?.effectiveTarget ?? target.targetChat ?? 'GLOBAL'} count=${matches.length} eligible=${eligibleMatches.length} selected=${candidateMatches.length} mode=${questionMatches.length ? 'question' : 'latest_message'}`);
        const normalizedTargetChat = normalizeHandle(
          resolvedTarget?.effectiveTarget ??
            target.targetChat ??
            (candidateMatches[0]?.chatUsername ? `@${candidateMatches[0].chatUsername}` : candidateMatches[0]?.chatId ?? null),
        );
        if (isSocialCategory(target) && normalizedTargetChat) {
          if (recentSocialOutreach.has(normalizedTargetChat) || socialQueuedThisCycle.has(normalizedTargetChat)) {
            console.info(
              `[${new Date().toISOString()}] social target rate-limited: target=${normalizedTargetChat}`,
            );
            return;
          }
        }
        for (const match of candidateMatches) {
          if (tasksCreated >= config.communityMaxTasksPerCycle) {
            break;
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
            targetChat:
              resolvedTarget?.effectiveTarget ??
              target.targetChat ??
              (match.chatUsername ? `@${match.chatUsername}` : match.chatId),
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
              requestedTargetChat: target.targetChat,
              effectiveTargetChat: resolvedTarget?.effectiveTarget ?? target.targetChat,
              replyToMessageId: Number(match.id),
              recommendBotUrl: config.recommendBotUrl,
              category: target.metadata?.category ?? null,
              workflow: target.metadata?.workflow ?? null,
              noPromoToday: target.metadata?.noPromoToday === true,
              surroundingMessages: await fetchTelegramMessageWindowWithClient(client, {
                targetChat:
                  resolvedTarget?.effectiveTarget ??
                  target.targetChat ??
                  (match.chatUsername ? `@${match.chatUsername}` : match.chatId ?? null),
                centerMessageId: Number(match.id),
                before: 3,
                after: 3,
              }),
            },
          });
          tasksCreated += 1;
          if (isSocialCategory(target) && normalizedTargetChat) {
            socialQueuedThisCycle.add(normalizedTargetChat);
          }
        }
      });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      if (isCommunityAccessLossError(error)) {
        console.info(
          `[${new Date().toISOString()}] community target disabled after access loss: target=${target.targetChat ?? "GLOBAL"} error=${errorMessage}`,
        );
        await setSofiaSearchTargetEnabled(target.id, false, {
          disabledReason: "access_lost",
          disabledAt: new Date().toISOString(),
          accessError: errorMessage,
        });
        await markSofiaSearchTargetChecked(target.id);
        continue;
      }
      console.info(
        `[${new Date().toISOString()}] community target disabled after resolve failure: target=${target.targetChat ?? "GLOBAL"} error=${errorMessage}`,
      );
      await setSofiaSearchTargetEnabled(target.id, false, {
        disabledReason: "resolve_failure",
        disabledAt: new Date().toISOString(),
        resolveError: errorMessage,
      });
      await markSofiaSearchTargetChecked(target.id);
      continue;
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
  channelTasksCreated: number;
  draftsCreated: number;
  sentCount: number;
}> {
  const inbox = await ingestSofiaInbox(config);
  await maybeSuggestRelocationCommunities(config);
  await maybeProcessCommunityApprovals(config);
  await maybeProcessCommunityDraftApprovals(config);
  const outreach = await runSofiaSearchSchedulerOnce(config);
  const channelTasksCreated = await maybeScheduleOwnedChannelPosts(config);
  const draftsCreated = await runSofiaGenerationBatch(config, config.generationBatchSize);
  await maybeRequestCommunityDraftApproval(config);
  const sentCount = config.autoSendApproved ? await sendApprovedSofiaTasks(config, config.generationBatchSize) : 0;
  await maybeSendOutreachHourlyReport(config);

  return {
    inboxTasksCreated: inbox.tasksCreated,
    outreachTasksCreated: outreach.tasksCreated,
    channelTasksCreated,
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
        `  channel_tasks=${result.channelTasksCreated}`,
        `  drafts=${result.draftsCreated}`,
        `  sent=${result.sentCount}`,
      ].join("\n") + "\n",
    );
  };

  try {
    await runCycle();
  } catch (error) {
    process.stderr.write(
      `[${new Date().toISOString()}] Sofia scheduler failed: ${error instanceof Error ? error.stack ?? error.message : String(error)}\n`,
    );
  }
  setInterval(() => {
    void runCycle().catch((error) => {
      process.stderr.write(
        `[${new Date().toISOString()}] Sofia scheduler failed: ${error instanceof Error ? error.stack ?? error.message : String(error)}\n`,
      );
    });
  }, intervalMs);
}
