function buildPromptMessages(payload) {
  const { question, spread, cards } = payload;

  const system = [
    'You are an insightful tarot reader for Basil\'s Arcana.',
    'Tone: calm, reflective, grounded, practical, non-deterministic.',
    'Avoid absolute predictions and avoid the word "will". Use "may", "could", "suggests", "likely".',
    'Do not give medical, legal, or financial directives.',
    'Reference the user question explicitly.',
    'Write one section per spread position.',
    'If the spread has three cards, mention relationships or tensions between cards.',
    'Output strict JSON only with keys: tldr, sections, why, action, fullText.',
    'Each section must have: positionId, title, text.',
    'No markdown, no extra keys.'
  ].join(' ');

  const user = {
    question,
    spread,
    cards
  };

  return [
    { role: 'system', content: system },
    {
      role: 'user',
      content: `Use this input to generate the reading:\n${JSON.stringify(user, null, 2)}`
    }
  ];
}

module.exports = { buildPromptMessages };
