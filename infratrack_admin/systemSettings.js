export const DEFAULT_SYSTEM_SETTINGS = {
  newReportAlerts: false,
  reportAlerts: true,
  duplicateAlerts: true,
  lowSeverityEscalationHours: 96,
  mediumSeverityEscalationHours: 72,
  highSeverityEscalationHours: 48,
};

const booleanSettingKeys = [
  "newReportAlerts",
  "reportAlerts",
  "duplicateAlerts",
];

const escalationSettingRanges = {
  lowSeverityEscalationHours: [1, 8760],
  mediumSeverityEscalationHours: [1, 8760],
  highSeverityEscalationHours: [1, 8760],
};

export function normalizeSystemSettings(value = {}) {
  const settings = { ...DEFAULT_SYSTEM_SETTINGS };
  for (const key of booleanSettingKeys) {
    if (typeof value[key] === "boolean") settings[key] = value[key];
  }
  for (const [key, [minimum, maximum]] of Object.entries(
    escalationSettingRanges,
  )) {
    const setting = value[key];
    if (
      Number.isInteger(setting) &&
      setting >= minimum &&
      setting <= maximum
    ) {
      settings[key] = setting;
    }
  }
  return settings;
}

export function validateSystemSettingsUpdate(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return { valid: false, error: "Settings must be provided as an object." };
  }

  for (const key of Object.keys(value)) {
    if (
      !booleanSettingKeys.includes(key) &&
      !Object.hasOwn(escalationSettingRanges, key)
    ) {
      return { valid: false, error: `Unsupported system setting: ${key}.` };
    }
  }

  for (const key of booleanSettingKeys) {
    if (Object.hasOwn(value, key) && typeof value[key] !== "boolean") {
      return { valid: false, error: `${key} must be true or false.` };
    }
  }

  for (const [key, [minimum, maximum]] of Object.entries(
    escalationSettingRanges,
  )) {
    if (!Object.hasOwn(value, key)) continue;
    if (
      !Number.isInteger(value[key]) ||
      value[key] < minimum ||
      value[key] > maximum
    ) {
      return {
        valid: false,
        error: `${key} must be a whole number from ${minimum} to ${maximum}.`,
      };
    }
  }

  return { valid: true, settings: value };
}
