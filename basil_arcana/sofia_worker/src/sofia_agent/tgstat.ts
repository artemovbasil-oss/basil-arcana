import type { SofiaAgentConfig } from "../config";

export interface TgstatCommunityCandidate {
  category: string;
  title: string;
  sourceUsername: string | null;
  targetChat: string;
  peerType: "chat" | "channel";
  about: string | null;
  link: string | null;
}

interface TgstatSearchItem {
  peer_type?: string;
  username?: string;
  title?: string;
  about?: string;
  link?: string;
}

function normalizeHandle(value: string | null | undefined): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.startsWith("@") ? trimmed.toLowerCase() : `@${trimmed.toLowerCase()}`;
}

function extractTelegramTargets(text: string | null | undefined): string[] {
  if (!text) return [];
  const results = new Set<string>();
  const handleRegex = /@([A-Za-z0-9_]{4,})/g;
  const linkRegex = /(?:https?:\/\/)?t\.me\/([A-Za-z0-9_+]{4,})/gi;
  let m: RegExpExecArray | null;
  while ((m = handleRegex.exec(text))) {
    const handle = normalizeHandle(m[1]);
    if (handle) results.add(handle);
  }
  while ((m = linkRegex.exec(text))) {
    const raw = m[1];
    if (raw.startsWith('+')) continue;
    const handle = normalizeHandle(raw);
    if (handle) results.add(handle);
  }
  return Array.from(results);
}

function extractTargetChat(item: TgstatSearchItem): string | null {
  const direct = normalizeHandle(item.username);
  if (item.peer_type === "chat" && direct) {
    return direct;
  }
  const fromAbout = extractTelegramTargets(item.about);
  const fromLink = extractTelegramTargets(item.link);
  const candidates = [...fromAbout, ...fromLink];
  for (const candidate of candidates) {
    if (candidate !== direct) return candidate;
  }
  return null;
}

export async function fetchTgstatCommunityCandidates(config: SofiaAgentConfig): Promise<TgstatCommunityCandidate[]> {
  if (!config.tgstatApiToken || !config.tgstatSyncEnabled) {
    return [];
  }

  const out: TgstatCommunityCandidate[] = [];
  const seen = new Set<string>();

  for (const category of config.tgstatCategories) {
    const params = new URLSearchParams({
      token: config.tgstatApiToken,
      category,
      peer_type: "all",
      country: config.tgstatCountry,
      language: config.tgstatLanguage,
      limit: String(config.tgstatLimitPerCategory),
    });
    const res = await fetch(`https://api.tgstat.ru/channels/search?${params.toString()}`);
    if (!res.ok) {
      throw new Error(`TGStat search failed for category ${category}: HTTP ${res.status}`);
    }
    const data = (await res.json()) as { status?: string; response?: { items?: TgstatSearchItem[] }; error?: string };
    if (data.status !== "ok") {
      throw new Error(`TGStat search failed for category ${category}: ${data.error ?? "unknown error"}`);
    }
    for (const item of data.response?.items ?? []) {
      const targetChat = extractTargetChat(item);
      if (!targetChat || seen.has(targetChat)) continue;
      seen.add(targetChat);
      out.push({
        category,
        title: item.title?.trim() || targetChat,
        sourceUsername: normalizeHandle(item.username),
        targetChat,
        peerType: item.peer_type === "chat" ? "chat" : "channel",
        about: item.about?.trim() || null,
        link: item.link?.trim() || null,
      });
    }
  }

  return out;
}
