function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function validatePositions(positions) {
  if (!Array.isArray(positions) || positions.length === 0) {
    return 'spread.positions must be a non-empty array';
  }

  for (const position of positions) {
    if (!isNonEmptyString(position.id) || !isNonEmptyString(position.title)) {
      return 'spread.positions entries must include id and title';
    }
  }

  return null;
}

function validateCards(cards) {
  if (!Array.isArray(cards) || cards.length === 0) {
    return 'cards must be a non-empty array';
  }

  for (const card of cards) {
    if (
      !isNonEmptyString(card.positionId) ||
      !isNonEmptyString(card.positionTitle) ||
      !isNonEmptyString(card.cardId) ||
      !isNonEmptyString(card.cardName)
    ) {
      return 'cards entries must include positionId, positionTitle, cardId, cardName';
    }
    if (!Array.isArray(card.keywords) || card.keywords.length === 0) {
      return 'cards entries must include keywords array';
    }
    if (!card.meaning || typeof card.meaning !== 'object') {
      return 'cards entries must include meaning';
    }
    const meaning = card.meaning;
    if (
      !isNonEmptyString(meaning.general) ||
      !isNonEmptyString(meaning.light) ||
      !isNonEmptyString(meaning.shadow) ||
      !isNonEmptyString(meaning.advice)
    ) {
      return 'cards meaning must include general, light, shadow, advice';
    }
  }

  return null;
}

function validateReadingRequest(body) {
  if (!body || typeof body !== 'object') {
    return 'Request body must be an object';
  }

  const { question, spread, cards, tone } = body;
  if (!isNonEmptyString(question)) {
    return 'question is required';
  }
  if (!spread || typeof spread !== 'object') {
    return 'spread is required';
  }
  if (!isNonEmptyString(spread.id) || !isNonEmptyString(spread.name)) {
    return 'spread must include id and name';
  }
  const positionError = validatePositions(spread.positions);
  if (positionError) {
    return positionError;
  }

  const cardsError = validateCards(cards);
  if (cardsError) {
    return cardsError;
  }

  if (tone && typeof tone !== 'string') {
    return 'tone must be a string';
  }

  return null;
}

module.exports = { validateReadingRequest };
