import test from 'node:test';
import assert from 'node:assert/strict';
import { saveAuthSession, clearAuthSession, getStoredAuthSession } from './authSession.js';

function createStorage() {
  const store = new Map();
  return {
    getItem(key) { return store.has(key) ? store.get(key) : null; },
    setItem(key, value) { store.set(key, String(value)); },
    removeItem(key) { store.delete(key); },
    clear() { store.clear(); },
  };
}

test('remember me stores the session in localStorage', () => {
  globalThis.localStorage = createStorage();
  globalThis.sessionStorage = createStorage();

  saveAuthSession({
    token: 'remembered-token',
    user: { id: 7, name: 'Admin User', role: 'admin' },
    rememberMe: true,
    email: 'admin@infratrack.test',
  });

  assert.equal(globalThis.localStorage.getItem('infratrack.adminToken'), 'remembered-token');
  assert.equal(globalThis.sessionStorage.getItem('infratrack.adminToken'), null);
  assert.equal(globalThis.localStorage.getItem('infratrack.adminRememberMe'), 'true');
  assert.equal(globalThis.localStorage.getItem('infratrack.adminRememberedEmail'), 'admin@infratrack.test');
});

test('non-remembered logins stay in session storage and are not restored automatically', () => {
  globalThis.localStorage = createStorage();
  globalThis.sessionStorage = createStorage();

  saveAuthSession({
    token: 'session-token',
    user: { id: 9, name: 'Staff User', role: 'barangay_staff' },
    rememberMe: false,
    email: 'staff@infratrack.test',
  });

  assert.equal(globalThis.sessionStorage.getItem('infratrack.adminToken'), 'session-token');
  assert.equal(globalThis.localStorage.getItem('infratrack.adminToken'), null);
  assert.equal(globalThis.localStorage.getItem('infratrack.adminRememberMe'), 'false');
  assert.equal(globalThis.localStorage.getItem('infratrack.adminRememberedEmail'), null);
  assert.equal(getStoredAuthSession().token, 'session-token');

  clearAuthSession();
  assert.equal(globalThis.sessionStorage.getItem('infratrack.adminToken'), null);
  assert.equal(globalThis.localStorage.getItem('infratrack.adminToken'), null);
});

test('api requests include the session token when the user did not choose remember me', async () => {
  globalThis.localStorage = createStorage();
  globalThis.sessionStorage = createStorage();
  globalThis.sessionStorage.setItem('infratrack.adminToken', 'session-token-123');

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, options = {}) => {
    const auth = options.headers?.get?.('Authorization');
    assert.equal(auth, 'Bearer session-token-123');
    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  };

  const { ok } = await import('./api.js').then(({ apiFetch }) => apiFetch('/issues'));
  assert.equal(ok, true);

  globalThis.fetch = originalFetch;
});
