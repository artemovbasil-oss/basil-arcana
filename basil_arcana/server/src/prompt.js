function buildPromptMessages(payload, mode = 'deep') {
  const { question, spread, cards, language, fastReading, responseConstraints } =
    payload;
  const constraints = responseConstraints || {};
  const tldrMax = constraints.tldrMaxChars || 180;
  const sectionMax = constraints.sectionMaxChars || 450;
  const whyMax = constraints.whyMaxChars || 300;
  const actionMax = constraints.actionMaxChars || 220;
  const isFast = mode === 'fast';

  const system = [
    'You are an insightful tarot reader for Basil\'s Arcana.',
    'Tone: calm, reflective, grounded, practical, non-deterministic.',
    'Avoid absolute predictions and avoid the word "will". Use "may", "could", "suggests", "likely".',
    'Do not give medical, legal, or financial directives.',
    'Reference the user question explicitly and tailor every section to it.',
    'Personalize the reading: connect each card to the user\'s situation, not just generic meanings.',
    'Weave in details from the question in the summary and action advice.',
    'Write one section per spread position.',
    'If the spread has three cards, mention relationships or tensions between cards.',
    `Respond in the same language as the user (${language || 'infer from the question'}).`,
    isFast
      ? `Fast mode: keep tldr <= ${tldrMax} chars, each section text <= ${sectionMax} chars, action <= ${actionMax} chars. Set "why" to an empty string.`
      : `Deep mode: keep tldr <= ${tldrMax} chars, each section text <= ${sectionMax} chars, why <= ${whyMax} chars, action <= ${actionMax} chars.`,
    'Output strict JSON only with keys: tldr, sections, why, action, fullText.',
    'Each section must have: positionId, title, text.',
    'No markdown, no extra keys.'
  ].join(' ');

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

module.exports = { buildPromptMessages };
