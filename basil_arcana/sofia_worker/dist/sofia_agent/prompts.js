"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildSofiaTaskPrompt = buildSofiaTaskPrompt;
function taskGoal(taskType) {
    if (taskType === "channel_post") {
        return "Write a strong Telegram channel post that feels native, opinionated, and worth sharing.";
    }
    if (taskType === "channel_comment") {
        return "Write a concise but high-signal public comment that adds value and invites engagement.";
    }
    if (taskType === "group_outreach") {
        return "Write a contextual outreach or group comment that earns trust without sounding spammy.";
    }
    if (taskType === "dm_reply") {
        return "Write a private-message reply that feels personal, grounded, and emotionally intelligent.";
    }
    return "Write a natal-chart response that is specific, compassionate, and actionable.";
}
function buildSofiaTaskPrompt(task, conversationContext, assistantGuidance) {
    const mediaKind = task.payload && typeof task.payload === "object" && "mediaKind" in task.payload
        ? String(task.payload.mediaKind ?? "")
        : "";
    const payload = JSON.stringify(task.payload ?? {}, null, 2);
    const parts = [
        `Task type: ${task.taskType}`,
        `Task title: ${task.title}`,
        task.sourceChannel ? `Source channel/group: ${task.sourceChannel}` : null,
        task.targetChat ? `Target chat or recipient: ${task.targetChat}` : null,
        `Goal: ${taskGoal(task.taskType)}`,
        "Important style constraints:",
        "- Keep it natural for Telegram.",
        "- Do not overuse emojis.",
        "- Do not sound like a generic AI assistant.",
        "- Do not greet repeatedly. If the thread already had an exchange with this user in the last 24 hours, continue naturally without saying hello again.",
        "- Avoid repetitive openings. Get to the substance of the reply quickly.",
        "- If the task is a reply, answer the user's emotional intent, not only the literal words.",
        "- If the task is about tarot or natal charts, give practical next steps, not vague abstraction.",
        "- Reply in the same language the user used in their latest message unless the payload explicitly says otherwise.",
        "- If the task is for the owned Telegram channel @estartarot, write in Russian unless the payload explicitly says otherwise.",
        mediaKind
            ? `- The inbound message includes a ${mediaKind} attachment. If image contents are not directly available in the payload, do not pretend you saw them. Acknowledge the attachment and ask for the minimum missing details needed to help.`
            : null,
        conversationContext ? `Recent thread context:\n${conversationContext}` : null,
        assistantGuidance ? `Reply guidance:\n${assistantGuidance}` : null,
        `Structured task payload:\n${payload}`,
        "Return a JSON object with keys: draft_text, short_rationale, risk_flags.",
    ].filter(Boolean);
    return parts.join("\n\n");
}
