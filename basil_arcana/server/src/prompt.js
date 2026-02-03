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
    'Tone: warm, supportive, gently encouraging. Avoid negative framing.',
    'Avoid absolute predictions and avoid the word "will". Use "may", "could", "suggests", "likely".',
    'Do not give medical, legal, or financial directives.',
    'Generate a single coherent message, not bullet spam.',
    'Start with a compact spread diagram using the drawn cards.',
    'If there is 1 card, render: [CardName].',
    'If there are 3 cards, render: [Left: CardName] [Center: CardName] [Right: CardName].',
    'Use neutral titles Left / Center / Right even if position titles differ.',
    'After the diagram, explain the interaction in 1-2 sentences: Center anchors the theme, Left feeds it, Right shows the direction it tends toward.',
    'Then write two sections labeled exactly "Relationships —" and "Career —" with short paragraphs.',
    'After each paragraph, add one gentle advice line.',
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

module.exports = { buildPromptMessages, buildDetailsPrompt };
