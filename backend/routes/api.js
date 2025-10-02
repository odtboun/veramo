const express = require('express');
const router = express.Router();

// API routes
router.get('/status', (req, res) => {
  res.json({ 
    status: 'OK', 
    service: 'Veramo API',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

router.get('/user', (req, res) => {
  res.json({
    id: 1,
    name: 'Veramo User',
    email: 'user@veramo.app'
  });
});

module.exports = router;
