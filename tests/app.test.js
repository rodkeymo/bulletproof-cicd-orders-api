const request = require('supertest');
const { createApp } = require('../src/app');

const app = createApp();

describe('health & readiness', () => {
  test('GET /health returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('GET /ready returns 200', async () => {
    const res = await request(app).get('/ready');
    expect(res.status).toBe(200);
  });
});

describe('orders API', () => {
  test('GET /orders returns empty array initially', async () => {
    const res = await request(app).get('/orders');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('POST /orders creates an order', async () => {
    const res = await request(app).post('/orders').send({ item: 'widget', quantity: 3 });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ item: 'widget', quantity: 3 });
    expect(res.body.id).toBeDefined();
  });

  test('POST /orders rejects invalid payload', async () => {
    const res = await request(app).post('/orders').send({ item: 'widget' });
    expect(res.status).toBe(400);
  });

  test('GET /orders/:id returns 404 for missing order', async () => {
    const res = await request(app).get('/orders/9999');
    expect(res.status).toBe(404);
  });

  test('GET /orders/:id returns created order', async () => {
    const create = await request(app).post('/orders').send({ item: 'gadget', quantity: 1 });
    const res = await request(app).get(`/orders/${create.body.id}`);
    expect(res.status).toBe(200);
    expect(res.body.item).toBe('gadget');
  });
});

describe('unknown routes', () => {
  test('returns 404 for unknown route', async () => {
    const res = await request(app).get('/nonexistent');
    expect(res.status).toBe(404);
  });
});
