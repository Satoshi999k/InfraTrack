export const STORAGE_KEYS = {
  token: 'infratrack.adminToken',
  user: 'infratrack.adminUser',
  rememberMe: 'infratrack.adminRememberMe',
  rememberedEmail: 'infratrack.adminRememberedEmail',
};

export function getRememberedEmail() {
  if (!globalThis.localStorage) return '';
  return globalThis.localStorage.getItem(STORAGE_KEYS.rememberedEmail) || '';
}

export function saveAuthSession({ token, user, rememberMe, email }) {
  if (!globalThis.localStorage || !globalThis.sessionStorage) {
    return;
  }

  const safeUser = typeof user === 'string' ? user : JSON.stringify(user ?? null);

  if (rememberMe) {
    globalThis.localStorage.setItem(STORAGE_KEYS.token, token);
    globalThis.localStorage.setItem(STORAGE_KEYS.user, safeUser);
    globalThis.localStorage.setItem(STORAGE_KEYS.rememberMe, 'true');
    if (email) {
      globalThis.localStorage.setItem(STORAGE_KEYS.rememberedEmail, email.trim());
    }

    globalThis.sessionStorage.removeItem(STORAGE_KEYS.token);
    globalThis.sessionStorage.removeItem(STORAGE_KEYS.user);
    globalThis.sessionStorage.removeItem(STORAGE_KEYS.rememberMe);
    return;
  }

  globalThis.sessionStorage.setItem(STORAGE_KEYS.token, token);
  globalThis.sessionStorage.setItem(STORAGE_KEYS.user, safeUser);
  globalThis.localStorage.setItem(STORAGE_KEYS.rememberMe, 'false');
  globalThis.localStorage.removeItem(STORAGE_KEYS.token);
  globalThis.localStorage.removeItem(STORAGE_KEYS.user);
  globalThis.localStorage.removeItem(STORAGE_KEYS.rememberedEmail);
  globalThis.sessionStorage.removeItem(STORAGE_KEYS.rememberMe);
}

export function getStoredAuthSession() {
  if (!globalThis.localStorage || !globalThis.sessionStorage) {
    return { token: '', user: null, rememberMe: false };
  }

  const token = globalThis.localStorage.getItem(STORAGE_KEYS.token) || globalThis.sessionStorage.getItem(STORAGE_KEYS.token) || '';
  const rawUser = globalThis.localStorage.getItem(STORAGE_KEYS.user) || globalThis.sessionStorage.getItem(STORAGE_KEYS.user);

  let user = null;
  if (rawUser) {
    try {
      user = JSON.parse(rawUser);
    } catch {
      user = null;
    }
  }

  return {
    token,
    user,
    rememberMe: globalThis.localStorage.getItem(STORAGE_KEYS.rememberMe) === 'true',
  };
}

export function clearAuthSession() {
  if (!globalThis.localStorage || !globalThis.sessionStorage) {
    return;
  }

  [STORAGE_KEYS.token, STORAGE_KEYS.user, STORAGE_KEYS.rememberMe].forEach((key) => {
    globalThis.localStorage.removeItem(key);
    globalThis.sessionStorage.removeItem(key);
  });
}
