const fs = require('fs');
const path = require('path');

const dataDir = path.join(__dirname, '..', 'assets', 'data');
const locales = ['en', 'ru', 'kk'];
const requiredStats = ['luck', 'power', 'love', 'clarity'];

function validateCard(locale, id, card) {
  const errors = [];
  if (!Array.isArray(card.keywords) || card.keywords.length === 0) {
    errors.push('keywords');
  }
  const meaning = card.meaning;
  if (!meaning || typeof meaning !== 'object') {
    errors.push('meaning');
  } else {
    if (!meaning.general || typeof meaning.general !== 'string') {
      errors.push('meaning.general');
    }
    if (!meaning.detailed || typeof meaning.detailed !== 'string') {
      errors.push('meaning.detailed');
    }
  }
  if (!card.funFact || typeof card.funFact !== 'string') {
    errors.push('funFact');
  }
  const stats = card.stats;
  if (!stats || typeof stats !== 'object') {
    errors.push('stats');
  } else {
    for (const key of requiredStats) {
      if (!Number.isInteger(stats[key])) {
        errors.push(`stats.${key}`);
      }
    }
  }
  if (errors.length > 0) {
    return { locale, id, errors };
  }
  return null;
}

let hasErrors = false;

for (const locale of locales) {
  const filePath = path.join(dataDir, `cards_${locale}.json`);
  const raw = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(raw);
  for (const [id, card] of Object.entries(data)) {
    if (id.startsWith('major_') || id.startsWith('wands_')) {
      const result = validateCard(locale, id, card);
      if (result) {
        hasErrors = true;
        console.error(`${result.locale} ${result.id}: missing ${result.errors.join(', ')}`);
      }
    }
  }
}

if (hasErrors) {
  process.exit(1);
}

console.log('All major and wands cards have required fields for en/ru/kk.');
