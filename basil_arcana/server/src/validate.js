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

  const { question, spread, cards, tone, language, fastReading } = body;
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
  if (language && typeof language !== 'string') {
    return 'language must be a string';
  }

  if (fastReading != null) {
    if (typeof fastReading !== 'object') {
      return 'fastReading must be an object';
    }
    if (fastReading.tldr && typeof fastReading.tldr !== 'string') {
      return 'fastReading.tldr must be a string';
    }
    if (fastReading.action && typeof fastReading.action !== 'string') {
      return 'fastReading.action must be a string';
    }
    if (fastReading.sections && !Array.isArray(fastReading.sections)) {
      return 'fastReading.sections must be an array';
    }
  }

  return null;
}

function validateDetailsRequest(body) {
  if (!body || typeof body !== 'object') {
    return 'Request body must be an object';
  }

  const { question, spread, cards, locale } = body;
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

  if (!isNonEmptyString(locale)) {
    return 'locale is required';
  }
  if (!['en', 'ru', 'kk'].includes(locale)) {
    return 'locale must be one of en, ru, kk';
  }

  return null;
}

function validateNatalChartRequest(body) {
  if (!body || typeof body !== 'object') {
    return 'Request body must be an object';
  }

  const { birthDate, birthTime, language } = body;
  if (!isNonEmptyString(birthDate)) {
    return 'birthDate is required';
  }
  if (birthTime != null && typeof birthTime !== 'string') {
    return 'birthTime must be a string';
  }
  if (!isNonEmptyString(language)) {
    return 'language is required';
  }
  if (!['en', 'ru', 'kk'].includes(language)) {
    return 'language must be one of en, ru, kk';
  }

  return null;
}

function validateCompatibilityRequest(body) {
  if (!body || typeof body !== 'object') {
    return 'Request body must be an object';
  }

  const { personOne, personTwo, language } = body;
  if (!personOne || typeof personOne !== 'object') {
    return 'personOne is required';
  }
  if (!personTwo || typeof personTwo !== 'object') {
    return 'personTwo is required';
  }
  const checkPerson = (person, key) => {
    if (!isNonEmptyString(person.name)) {
      return `${key}.name is required`;
    }
    if (!isNonEmptyString(person.birthDate)) {
      return `${key}.birthDate is required`;
    }
    if (!isNonEmptyString(person.birthTime)) {
      return `${key}.birthTime is required`;
    }
    return null;
  };
  const p1Error = checkPerson(personOne, 'personOne');
  if (p1Error) {
    return p1Error;
  }
  const p2Error = checkPerson(personTwo, 'personTwo');
  if (p2Error) {
    return p2Error;
  }
  if (!isNonEmptyString(language)) {
    return 'language is required';
  }
  if (!['en', 'ru', 'kk'].includes(language)) {
    return 'language must be one of en, ru, kk';
  }

  return null;
}

module.exports = {
  validateReadingRequest,
  validateDetailsRequest,
  validateNatalChartRequest,
  validateCompatibilityRequest,
};
