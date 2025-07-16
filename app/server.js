const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.VERSION || 'blue';
const BUILD_NUMBER = process.env.BUILD_NUMBER || '1';

app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    message: `Hello from ${VERSION} environment!`,
    version: VERSION,
    build: BUILD_NUMBER,
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname()
  });
});

app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    version: VERSION,
    uptime: process.uptime()
  });
});

app.get('/version', (req, res) => {
  res.json({ version: VERSION, build: BUILD_NUMBER });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} - ${VERSION} version`);
});
