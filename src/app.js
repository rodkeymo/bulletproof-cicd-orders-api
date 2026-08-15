const express = require('express');

function createApp() {
  const app = express();
  app.use(express.json());

  // Liveness probe — used by ECS container health check
  app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok', service: 'orders-api', ts: new Date().toISOString() });
  });

  // Readiness probe — used by ALB target group health check
  app.get('/ready', (req, res) => {
    res.status(200).json({ status: 'ready' });
  });

  // In-memory "orders" resource — stands in for a real SaaS domain object
  const orders = new Map();
  let nextId = 1;

  app.get('/orders', (req, res) => {
    res.json(Array.from(orders.values()));
  });

  app.post('/orders', (req, res) => {
    const { item, quantity } = req.body || {};
    if (!item || typeof quantity !== 'number' || quantity <= 0) {
      return res.status(400).json({ error: 'item (string) and quantity (positive number) are required' });
    }
    const order = { id: nextId++, item, quantity, createdAt: new Date().toISOString() };
    orders.set(order.id, order);
    res.status(201).json(order);
  });

  app.get('/orders/:id', (req, res) => {
    const order = orders.get(Number(req.params.id));
    if (!order) return res.status(404).json({ error: 'not found' });
    res.json(order);
  });

  app.use((req, res) => {
    res.status(404).json({ error: 'route not found' });
  });

  return app;
}

module.exports = { createApp };
