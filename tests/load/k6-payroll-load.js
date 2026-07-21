import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 50 },  // Ramp up to 50 users
    { duration: '1m', target: 110 },  // Ramp up to 110 VUs (100 Workers + 10 Foremen)
    { duration: '2m', target: 110 },  // Sustained load test
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete within 500ms
    http_req_failed: ['rate<0.01'],    // HTTP error rate must be < 1%
  },
};

const BASE_URL = __ENV.TARGET_URL || 'http://localhost:3000/v1';

export default function () {
  // 1. Worker Clock-in / Health Check simulation
  const healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    'health status 200': (r) => r.status === 200,
  });

  // 2. Simulated Auth Login for Worker / Foreman
  const payload = JSON.stringify({
    phone: '+998901000001',
    pin: '1234',
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const loginRes = http.post(`${BASE_URL}/iam/auth/login`, payload, params);
  const loginSuccess = check(loginRes, {
    'login status 200 or 201': (r) => r.status === 200 || r.status === 201,
  });

  let token = '';
  if (loginSuccess && loginRes.json()) {
    token = loginRes.json('accessToken') || '';
  }

  const authParams = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
  };

  // 3. Worker Operation Submission simulation
  if (token) {
    const entryPayload = JSON.stringify({
      operationId: '11111111-1111-1111-1111-111111111111',
      quantity: 50,
    });
    const entryRes = http.post(`${BASE_URL}/production/entries`, entryPayload, authParams);
    check(entryRes, {
      'production entry recorded or handled': (r) => r.status < 500,
    });

    // 4. Batch Payroll Calculation simulation (Director load)
    const payrollRes = http.get(`${BASE_URL}/payroll/calculate?period=2026-07`, authParams);
    check(payrollRes, {
      'payroll response received': (r) => r.status < 500,
    });
  }

  sleep(1);
}
