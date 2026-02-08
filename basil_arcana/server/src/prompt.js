function buildPromptMessages(payload, mode = 'deep') {
  const { question, spread, cards, language, fastReading, responseConstraints } =
    payload;
  const constraints = responseConstraints || {};
  const tldrMax = constraints.tldrMaxChars || 180;
  const sectionMax = constraints.sectionMaxChars || 450;
  const whyMax = constraints.whyMaxChars || 300;
  const actionMax = constraints.actionMaxChars || 220;
  const isFast = mode === 'fast';
  const isLifeAreas = mode === 'life_areas';
  const isDetails = mode === 'details_relationships_career';

  const system = [
    'You are an insightful tarot reader for Basil\'s Arcana.',
    isDetails
      ? 'Tone: calm, warm, encouraging, gentle, non-deterministic.'
      : 'Tone: calm, reflective, grounded, practical, non-deterministic.',
    'Avoid absolute predictions and avoid the word "will". Use "may", "could", "suggests", "likely".',
    'Do not give medical, legal, or financial directives.',
    'Reference the user question explicitly and tailor every section to it.',
    'Personalize the reading: connect each card to the user\'s situation, not just generic meanings.',
    'Weave in details from the question in the summary and action advice.',
    isDetails
      ? 'Write exactly two sections: one for Relationships and one for Career, each grounded in the selected cards and the user question.'
      : isLifeAreas
          ? 'Write exactly two sections: one for Love and one for Career, each grounded in the selected cards and the user question.'
          : 'Write one section per spread position.',
    'If the spread has three cards, mention relationships or tensions between cards.',
    `Respond in the same language as the user (${language || 'infer from the question'}).`,
    isFast
      ? `Fast mode: keep tldr <= ${tldrMax} chars, each section text <= ${sectionMax} chars, action <= ${actionMax} chars. Set "why" to an empty string.`
      : `Deep mode: keep tldr <= ${tldrMax} chars, each section text <= ${sectionMax} chars, why <= ${whyMax} chars, action <= ${actionMax} chars.`,
    isLifeAreas
      ? 'Life areas mode: focus only on Love and Career. Use the cards and the question for concrete, grounded insights.'
      : null,
    isDetails
      ? 'Details mode: focus only on Relationships and Career. Keep the tone friendly and warm, avoid negativity, and avoid overly concrete claims.'
      : null,
    'Output strict JSON only with keys: tldr, sections, why, action, fullText.',
    'Each section must have: positionId, title, text.',
    'No markdown, no extra keys.'
  ]
      .filter((line) => line != null)
      .join(' ');

  const user = {
    question,
    spread,
    cards,
    language
  };
  if (!isFast && fastReading) {
    user.fastReading = fastReading;
  }

  return [
    { role: 'system', content: system },
    {
      role: 'user',
      content: `Use this input to generate the reading:\n${JSON.stringify(user, null, 2)}`
    }
  ];
}

function buildDetailsPrompt(payload) {
  const { question, spread, cards, locale } = payload;
  const system = [
    'You are an insightful tarot reader for Basil\'s Arcana.',
    'Tone: strict but caring grandmother oracle. Warm, grounded, wise, and gently encouraging.',
    'Avoid negative framing.',
    'Avoid absolute predictions and avoid the word "will". Use "may", "could", "suggests", "likely".',
    'Do not give medical, legal, or financial directives.',
    'Return plain text only with no markdown, no symbols, no brackets, and no bullet points.',
    'Structure the response as plain text with these sections in order:',
    '1) Short summary (1-2 sentences).',
    '2) Relationships (1-2 short paragraphs).',
    '3) Career (1-2 short paragraphs).',
    '4) Grounded advice (1 short paragraph).',
    'If there are three cards, explain the interaction between Left, Center, and Right, and state that the Center card is the main influence.',
    `Respond in the requested locale (${locale || 'infer from the question'}).`,
  ].join(' ');

  const user = {
    question,
    spread,
    cards,
    locale,
  };

  return [
    { role: 'system', content: system },
    {
      role: 'user',
      content: `Use this input to generate the details:\n${JSON.stringify(user, null, 2)}`,
    },
  ];
}

function buildNatalChartPrompt(payload) {
  const { birthDate, birthTime, language } = payload;
  const system = [
    'You are a warm, grounded astrologer for Basil\'s Arcana.',
    'Provide a concise natal chart interpretation based on the birth data.',
    'If birth time is missing, mention that the interpretation is general and time is approximate.',
    'Avoid absolute predictions and avoid the word "will". Use "may", "could", "suggests", "likely".',
    'Do not give medical, legal, or financial directives.',
    'Keep the response short (3-5 short paragraphs) and text-only.',
    `Respond in the requested language (${language || 'infer from the input'}).`,
  ].join(' ');

  const user = {
    birthDate,
    birthTime: birthTime || null,
    language,
  };

  return [
    { role: 'system', content: system },
    {
      role: 'user',
      content: `Use this birth data to generate a natal chart overview:\n${JSON.stringify(
        user,
        null,
        2
      )}`,
    },
  ];
}

module.exports = { buildPromptMessages, buildDetailsPrompt, buildNatalChartPrompt };
