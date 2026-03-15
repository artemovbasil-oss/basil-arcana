"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateSofiaDraft = generateSofiaDraft;
async function generateSofiaDraft(input) {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${input.apiKey}`,
        },
        body: JSON.stringify({
            model: input.model,
            temperature: 0.8,
            response_format: { type: "json_object" },
            messages: [
                { role: "system", content: input.systemPrompt },
                { role: "user", content: input.taskPrompt },
            ],
        }),
    });
    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`OpenAI request failed: ${response.status} ${errorText}`);
    }
    const data = (await response.json());
    const rawText = String(data.choices?.[0]?.message?.content ?? "").trim();
    if (!rawText) {
        throw new Error("OpenAI returned an empty draft");
    }
    let parsed;
    try {
        parsed = JSON.parse(rawText);
    }
    catch (error) {
        throw new Error(`OpenAI returned invalid JSON: ${String(error)}`);
    }
    const draftText = String(parsed.draft_text ?? "").trim();
    if (!draftText) {
        throw new Error("OpenAI JSON did not contain draft_text");
    }
    const shortRationale = String(parsed.short_rationale ?? "").trim();
    const riskFlags = Array.isArray(parsed.risk_flags)
        ? parsed.risk_flags.map((item) => String(item)).filter(Boolean)
        : [];
    return {
        draftText,
        shortRationale,
        riskFlags,
        rawText,
    };
}
