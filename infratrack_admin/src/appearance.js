export const DEFAULT_APPEARANCE = {
  theme: "light",
  accent: "teal",
  typeface: "inter",
  textSize: "regular",
  corners: "rounded",
  highContrast: false,
};

export const ACCENT_COLORS = {
  teal: {
    value: "#1b8a83",
    soft: "#e4f2f0",
    action: "#176f69",
    actionHover: "#125c57",
  },
  blue: {
    value: "#2679d8",
    soft: "#e5f0ff",
    action: "#1f65b6",
    actionHover: "#19549a",
  },
  emerald: {
    value: "#17885c",
    soft: "#e2f3eb",
    action: "#146d4b",
    actionHover: "#105b3e",
  },
  violet: {
    value: "#7651c9",
    soft: "#eee8fb",
    action: "#6843b8",
    actionHover: "#56369d",
  },
  amber: {
    value: "#a96d11",
    soft: "#f8edd9",
    action: "#81520d",
    actionHover: "#6d440a",
  },
  rose: {
    value: "#ca3f5c",
    soft: "#fae8ec",
    action: "#b83250",
    actionHover: "#9e2944",
  },
};

const themes = new Set(["light", "dark", "system"]);
const accents = new Set(Object.keys(ACCENT_COLORS));
const typefaces = new Set([
  "inter",
  "system",
  "arial",
  "roboto",
  "lato",
  "open-sans",
  "poppins",
  "nunito",
]);
const textSizes = new Set(["compact", "regular", "large"]);
const cornerStyles = new Set(["square", "rounded", "soft"]);
const appearanceTransitionTimers = new WeakMap();

export function normalizeAppearance(value) {
  return {
    theme: themes.has(value?.theme) ? value.theme : DEFAULT_APPEARANCE.theme,
    accent: accents.has(value?.accent)
      ? value.accent
      : DEFAULT_APPEARANCE.accent,
    typeface: typefaces.has(value?.typeface)
      ? value.typeface
      : DEFAULT_APPEARANCE.typeface,
    textSize: textSizes.has(value?.textSize)
      ? value.textSize
      : DEFAULT_APPEARANCE.textSize,
    corners: cornerStyles.has(value?.corners)
      ? value.corners
      : DEFAULT_APPEARANCE.corners,
    highContrast: value?.highContrast === true,
  };
}

export function readAppearance(storage) {
  const source = storage ?? globalThis.localStorage;
  const saved = source.getItem("infratrack.appearance");
  if (!saved) return { ...DEFAULT_APPEARANCE };

  try {
    return normalizeAppearance(JSON.parse(saved));
  } catch {
    return { ...DEFAULT_APPEARANCE };
  }
}

export function applyAppearance(
  value,
  root,
  prefersDark = false,
  transition = false,
) {
  const appearance = normalizeAppearance(value);
  const theme =
    appearance.theme === "system"
      ? prefersDark
        ? "dark"
        : "light"
      : appearance.theme;
  const accent = ACCENT_COLORS[appearance.accent];

  if (transition) {
    const existingTimer = appearanceTransitionTimers.get(root);
    if (existingTimer) globalThis.clearTimeout(existingTimer);
    root.dataset.appearanceTransition = "true";
    void root.offsetWidth;
  }

  root.dataset.theme = theme;
  root.dataset.themeChoice = appearance.theme;
  root.dataset.accent = appearance.accent;
  root.dataset.typeface = appearance.typeface;
  root.dataset.textSize = appearance.textSize;
  root.dataset.corners = appearance.corners;
  root.dataset.contrast = appearance.highContrast ? "high" : "normal";
  root.style.colorScheme = theme;
  root.style.setProperty("--user-accent", accent.value);
  root.style.setProperty("--user-accent-soft", accent.soft);
  root.style.setProperty("--user-action-accent", accent.action);
  root.style.setProperty("--user-action-accent-hover", accent.actionHover);

  if (transition) {
    const timer = globalThis.setTimeout(() => {
      delete root.dataset.appearanceTransition;
      appearanceTransitionTimers.delete(root);
    }, 460);
    appearanceTransitionTimers.set(root, timer);
  }

  return appearance;
}

export function saveAppearance(
  value,
  storage,
  root,
  prefersDark = false,
  transition = false,
  transitionOrigin = null,
) {
  const appearance = normalizeAppearance(value);
  const targetStorage = storage ?? globalThis.localStorage;
  const targetRoot = root ?? globalThis.document.documentElement;
  targetStorage.setItem("infratrack.appearance", JSON.stringify(appearance));

  const view = targetRoot.ownerDocument?.defaultView;
  const startViewTransition = targetRoot.ownerDocument?.startViewTransition;
  if (
    transition &&
    transitionOrigin &&
    typeof startViewTransition === "function" &&
    view
  ) {
    const bounds = transitionOrigin.getBoundingClientRect();
    const x = bounds.left + bounds.width / 2;
    const y = bounds.top + bounds.height / 2;
    const radius = Math.hypot(
      Math.max(x, view.innerWidth - x),
      Math.max(y, view.innerHeight - y),
    );

    targetRoot.style.setProperty("--theme-reveal-x", `${x}px`);
    targetRoot.style.setProperty("--theme-reveal-y", `${y}px`);
    targetRoot.style.setProperty("--theme-reveal-radius", `${radius}px`);
    startViewTransition.call(targetRoot.ownerDocument, () =>
      applyAppearance(appearance, targetRoot, prefersDark),
    );
    return appearance;
  }

  applyAppearance(appearance, targetRoot, prefersDark, transition);
  return appearance;
}

export function initializeAppearance({
  storage = globalThis.localStorage,
  root = globalThis.document.documentElement,
  mediaQuery = globalThis.matchMedia("(prefers-color-scheme: dark)"),
} = {}) {
  const update = (prefersDark, transition = false) =>
    applyAppearance(readAppearance(storage), root, prefersDark, transition);
  update(mediaQuery.matches);

  const handlePreferenceChange = (event) => {
    if (readAppearance(storage).theme === "system") update(event.matches, true);
  };
  mediaQuery.addEventListener("change", handlePreferenceChange);

  return () => mediaQuery.removeEventListener("change", handlePreferenceChange);
}
