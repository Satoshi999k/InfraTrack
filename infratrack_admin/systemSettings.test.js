import test from "node:test";
import assert from "node:assert/strict";
import {
  DEFAULT_SYSTEM_SETTINGS,
  normalizeSystemSettings,
  validateSystemSettingsUpdate,
} from "./systemSettings.js";

test("system settings use safe defaults and normalize stored values", () => {
  assert.deepEqual(normalizeSystemSettings(), DEFAULT_SYSTEM_SETTINGS);
  assert.deepEqual(
    normalizeSystemSettings({
      newReportAlerts: true,
      lowSeverityEscalationHours: 48,
      mediumSeverityEscalationHours: "36",
      highSeverityEscalationHours: 9000,
    }),
    {
      ...DEFAULT_SYSTEM_SETTINGS,
      newReportAlerts: true,
      lowSeverityEscalationHours: 48,
    },
  );
});

test("system settings updates accept supported notification and workflow values", () => {
  const settings = {
    newReportAlerts: true,
    reportAlerts: false,
    duplicateAlerts: true,
    lowSeverityEscalationHours: 24,
    mediumSeverityEscalationHours: 48,
    highSeverityEscalationHours: 72,
  };
  assert.deepEqual(validateSystemSettingsUpdate(settings), {
    valid: true,
    settings,
  });
});

test("notification preferences can be updated independently", () => {
  for (const key of [
    "newReportAlerts",
    "reportAlerts",
    "duplicateAlerts",
  ]) {
    assert.deepEqual(validateSystemSettingsUpdate({ [key]: false }), {
      valid: true,
      settings: { [key]: false },
    });
  }
});

test("system settings updates reject unsupported or invalid values", () => {
  assert.equal(
    validateSystemSettingsUpdate({ autoAssign: true }).valid,
    false,
  );
  assert.equal(
    validateSystemSettingsUpdate({ newReportAlerts: "true" }).valid,
    false,
  );
  for (const value of [0, -1, 1.5, 8761, "24"]) {
    assert.equal(
      validateSystemSettingsUpdate({ lowSeverityEscalationHours: value })
        .valid,
      false,
    );
  }
});
