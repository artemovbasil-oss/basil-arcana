const express = require('express');
const cors = require('cors');

const { buildPromptMessages } = require('./src/prompt');
const { createChatCompletion } = require('./src/openai_client');
const { validateReadingRequest } = require('./src/validate');

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true, name: 'basils-arcana' });
});

app.post('/api/reading/generate', async (req, res) => {
  const error = validateReadingRequest(req.body);
  if (error) {
    return res.status(400).json({ error });
  }

  try {
    const messages = buildPromptMessages(req.body);
    const result = await createChatCompletion(messages);
    return res.json(result);
  } catch (err) {
    return res.status(502).json({ error: 'upstream_failed' });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Basil's Arcana API listening on ${port}`);
});
