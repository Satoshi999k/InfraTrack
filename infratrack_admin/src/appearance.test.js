import test from "node:test";
import assert from "node:assert/strict";
import {
  ACCENT_COLORS,
  applyAppearance,
  initializeAppearance,
  normalizeAppearance,
  readAppearance,
  saveAppearance,
} from "./appearance.js";

function createStorage(initialValue = null) {
  const values = new Map();
  if (initialValue !== null) values.set("infratrack.appearance", initialValue);
  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
}

function createRoot() {
  const properties = new Map();
  return {
    dataset: {},
    style: {
      colorScheme: "",
      setProperty: (key, value) => properties.set(key, value),
      getPropertyValue: (key) => properties.get(key),
    },
  };
}

function contrastWithWhite(hexColor) {
  const channels = hexColor.match(/[a-f\d]{2}/gi).map((channel) => {
    const value = parseInt(channel, 16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  const luminance =
    channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
  return 1.05 / (luminance + 0.05);
}

test("normalizes unsupported appearance values to InfraTrack defaults", () => {
  assert.deepEqual(normalizeAppearance({ theme: "neon", accent: "invalid" }), {
    theme: "light",
    accent: "teal",
    typeface: "inter",
    textSize: "regular",
    corners: "rounded",
    highContrast: false,
  });
});

test("normalizes invalid text-size and corner preferences while preserving valid choices", () => {
  assert.deepEqual(
    normalizeAppearance({ textSize: "huge", corners: "pill" }),
    {
      theme: "light",
      accent: "teal",
      typeface: "inter",
      textSize: "regular",
      corners: "rounded",
      highContrast: false,
    },
  );
  assert.equal(
    normalizeAppearance({ textSize: "large", corners: "square" }).textSize,
    "large",
  );
  assert.equal(
    normalizeAppearance({ textSize: "large", corners: "square" }).corners,
    "square",
  );
});

test("supports all available typeface preferences", () => {
  const typefaces = [
    "inter",
    "system",
    "arial",
    "roboto",
    "lato",
    "open-sans",
    "poppins",
    "nunito",
  ];

  for (const typeface of typefaces) {
    const root = createRoot();
    const appearance = applyAppearance({ typeface }, root);
    assert.equal(appearance.typeface, typeface);
    assert.equal(root.dataset.typeface, typeface);
  }
});

test("normalizes high-contrast preference to a boolean", () => {
  assert.equal(normalizeAppearance({ highContrast: true }).highContrast, true);
  assert.equal(normalizeAppearance({ highContrast: "true" }).highContrast, false);
});

test("reads and saves appearance preferences in local storage", () => {
  const storage = createStorage();
  const root = createRoot();
  const appearance = saveAppearance(
    { theme: "dark", accent: "violet", typeface: "system" },
    storage,
    root,
  );

  assert.deepEqual(readAppearance(storage), appearance);
  assert.equal(root.dataset.theme, "dark");
  assert.equal(root.dataset.accent, "violet");
  assert.equal(root.dataset.typeface, "system");
  assert.equal(root.dataset.contrast, "normal");
  assert.equal(root.dataset.textSize, "regular");
  assert.equal(root.dataset.corners, "rounded");
  assert.equal(root.style.colorScheme, "dark");
  assert.equal(root.style.getPropertyValue("--user-accent"), "#7651c9");
  assert.equal(root.style.getPropertyValue("--user-action-accent"), "#6843b8");
  assert.equal(root.style.getPropertyValue("--user-action-accent-hover"), "#56369d");
});

test("persists and applies high-contrast preference", () => {
  const storage = createStorage();
  const root = createRoot();
  saveAppearance({ highContrast: true }, storage, root);

  assert.equal(readAppearance(storage).highContrast, true);
  assert.equal(root.dataset.contrast, "high");

  saveAppearance({ highContrast: false }, storage, root);
  assert.equal(readAppearance(storage).highContrast, false);
  assert.equal(root.dataset.contrast, "normal");
});

test("persists and applies text-size and corner preferences", () => {
  const storage = createStorage();
  const root = createRoot();
  const appearance = saveAppearance(
    { textSize: "large", corners: "soft" },
    storage,
    root,
  );

  assert.equal(readAppearance(storage).textSize, "large");
  assert.equal(readAppearance(storage).corners, "soft");
  assert.equal(root.dataset.textSize, "large");
  assert.equal(root.dataset.corners, "soft");
});

test("accent preferences update readable action colors", () => {
  const root = createRoot();
  const actionColors = new Set();

  for (const accent of Object.keys(ACCENT_COLORS)) {
    applyAppearance({ accent }, root);
    const actionColor = root.style.getPropertyValue("--user-action-accent");
    actionColors.add(actionColor);
    assert.ok(contrastWithWhite(actionColor) >= 4.5);
  }

  assert.equal(actionColors.size, Object.keys(ACCENT_COLORS).length);
});

test("theme view transition reveals from the selected control", () => {
  const storage = createStorage();
  const root = createRoot();
  let transitionUpdate;
  const document = {
    defaultView: { innerWidth: 1000, innerHeight: 800 },
    startViewTransition: (update) => {
      transitionUpdate = update;
      update();
    },
  };
  root.ownerDocument = document;
  const origin = {
    getBoundingClientRect: () => ({
      left: 100,
      top: 200,
      width: 80,
      height: 40,
    }),
  };

  saveAppearance(
    { theme: "dark" },
    storage,
    root,
    false,
    true,
    origin,
  );

  assert.equal(typeof transitionUpdate, "function");
  assert.equal(root.dataset.theme, "dark");
  assert.equal(root.dataset.appearanceTransition, undefined);
  assert.equal(root.style.getPropertyValue("--theme-reveal-x"), "140px");
  assert.equal(root.style.getPropertyValue("--theme-reveal-y"), "220px");
  assert.equal(root.style.getPropertyValue("--theme-reveal-radius"), `${Math.hypot(860, 580)}px`);
});

test("system appearance resolves from the device preference", () => {
  const root = createRoot();
  applyAppearance({ theme: "system" }, root, true);
  assert.equal(root.dataset.theme, "dark");
  assert.equal(root.dataset.themeChoice, "system");

  applyAppearance({ theme: "system" }, root, false);
  assert.equal(root.dataset.theme, "light");
});

test("appearance transitions are temporary when enabled", async () => {
  const root = createRoot();
  applyAppearance({ theme: "dark", accent: "violet" }, root, false, true);

  assert.equal(root.dataset.theme, "dark");
  assert.equal(root.dataset.appearanceTransition, "true");

  await new Promise((resolve) => globalThis.setTimeout(resolve, 500));
  assert.equal(root.dataset.appearanceTransition, undefined);
});

test("system appearance responds to device theme changes and cleans up", () => {
  const storage = createStorage(
    JSON.stringify({ theme: "system", accent: "teal", typeface: "inter" }),
  );
  const root = createRoot();
  const listeners = new Set();
  const mediaQuery = {
    matches: false,
    addEventListener: (event, listener) => listeners.add(listener),
    removeEventListener: (event, listener) => listeners.delete(listener),
  };

  const cleanup = initializeAppearance({ storage, root, mediaQuery });
  assert.equal(root.dataset.theme, "light");

  for (const listener of listeners) listener({ matches: true });
  assert.equal(root.dataset.theme, "dark");
  assert.equal(root.dataset.appearanceTransition, "true");

  cleanup();
  assert.equal(listeners.size, 0);
});

test("uses defaults when stored appearance JSON is malformed", () => {
  assert.deepEqual(readAppearance(createStorage("{")), {
    theme: "light",
    accent: "teal",
    typeface: "inter",
    textSize: "regular",
    corners: "rounded",
    highContrast: false,
  });
});
