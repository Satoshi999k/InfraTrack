import { createPortal } from "react-dom";
import { useEffect, useState } from "react";
import { CircleMarker, MapContainer, TileLayer } from "react-leaflet";
import {
  Check,
  Contrast,
  ExternalLink,
  Monitor,
  Moon,
  Palette,
  RotateCcw,
  Sun,
  Type,
  MapPin,
  X,
} from "lucide-react";
import { API_BASE, apiFetch } from "../api";
import { canManageSystemSettings } from "../../permissions";
import {
  ACCENT_COLORS,
  readAppearance,
  saveAppearance,
  DEFAULT_APPEARANCE,
} from "../appearance";
import { DEFAULT_SYSTEM_SETTINGS } from "../../systemSettings";

const defaultSettings = DEFAULT_SYSTEM_SETTINGS;
const auditLogPageSize = 20;

function isPublicIpAddress(value) {
  const ip = String(value || "").trim();
  if (!ip || ip === "::1" || ip === "127.0.0.1" || ip.toLowerCase() === "localhost") return false;
  if (/^(10\.|127\.|192\.168\.|169\.254\.)/.test(ip)) return false;
  if (/^172\.(1[6-9]|2\d|3[0-1])\./.test(ip)) return false;
  if (/^(fc|fd|fe8|fe9|fea|feb)/i.test(ip)) return false;
  return true;
}

export default function SettingsPage({ user, logsOnly = false }) {
  const isBarangayStaff = user?.role === "barangay_staff";
  const canManageSettings = canManageSystemSettings(user?.role);
  const [settings, setSettings] = useState(defaultSettings);
  const [saved, setSaved] = useState(false);
  const [settingsDirty, setSettingsDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [settingsLoaded, setSettingsLoaded] = useState(false);
  const [notificationSaveStatus, setNotificationSaveStatus] = useState("");
  const [settingsError, setSettingsError] = useState("");
  const [appearance, setAppearance] = useState(readAppearance);
  const [passwords, setPasswords] = useState({ current: "", next: "", confirm: "" });
  const [passwordMessage, setPasswordMessage] = useState("");
  const [dataMessage, setDataMessage] = useState("");
  const [backupPending, setBackupPending] = useState(false);
  const [teams, setTeams] = useState([]);
  const [selectedIpLog, setSelectedIpLog] = useState(null);
  const [teamForm, setTeamForm] = useState({ name: "", department: "", contactPhone: "" });
  const [logs, setLogs] = useState([]);
  const [auditTotal, setAuditTotal] = useState(0);
  const [auditPage, setAuditPage] = useState(0);
  const [auditLoading, setAuditLoading] = useState(false);
  const [logsError, setLogsError] = useState("");
  const [auditFilters, setAuditFilters] = useState({ user: "", action: "", barangay: "", from: "", to: "" });

  useEffect(() => {
    if (!user?.id || logsOnly || !canManageSettings) return;
    let active = true;
    apiFetch(`/settings?userId=${encodeURIComponent(user.id)}`)
      .then(async (response) => {
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || "Could not load system settings");
        if (active) {
          setSettings({ ...defaultSettings, ...data.settings });
          setSettingsLoaded(true);
        }
      })
      .catch((error) => {
        if (active) setSettingsError(error.message);
      });
    return () => {
      active = false;
    };
  }, [user?.id, logsOnly, canManageSettings]);

  useEffect(() => {
    if (!logsOnly || !user?.id || !["lgu", "admin", "barangay_staff"].includes(user.role)) return;
    const controller = new AbortController();
    const query = new URLSearchParams({
      adminId: user.id,
      limit: String(auditLogPageSize),
      offset: String(auditPage * auditLogPageSize),
      ...Object.fromEntries(Object.entries(auditFilters).filter(([, value]) => value)),
    });

    const loadLogs = async () => {
      setAuditLoading(true);
      setLogsError("");
      try {
        const response = await apiFetch(`/audit-logs?${query.toString()}`, { signal: controller.signal });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || "Could not load audit logs");
        setLogs(data.logs ?? []);
        setAuditTotal(Number(data.total) || 0);
      } catch (error) {
        if (error.name !== "AbortError") setLogsError(error.message);
      } finally {
        if (!controller.signal.aborted) setAuditLoading(false);
      }
    };

    loadLogs();
    return () => controller.abort();
  }, [user, auditFilters, logsOnly, auditPage]);

  const updateAuditFilter = (key, value) => {
    setAuditFilters((current) => ({ ...current, [key]: value }));
    setAuditPage(0);
  };

  const auditPageCount = Math.max(1, Math.ceil(auditTotal / auditLogPageSize));
  const auditStart = auditTotal ? auditPage * auditLogPageSize + 1 : 0;
  const auditEnd = Math.min((auditPage + 1) * auditLogPageSize, auditTotal);

  const parseDetails = (log) => {
    try { return log.details ? JSON.parse(log.details) : null; } catch { return null; }
  };

  const formatAuditValue = (value) => {
    if (value === null || value === undefined || value === "") return "—";
    if (typeof value === "string") return value;
    if (typeof value === "number" || typeof value === "boolean") return String(value);
    if (Array.isArray(value)) return value.length ? value.map((entry) => formatAuditValue(entry)).join(", ") : "[]";
    if (typeof value === "object") {
      return Object.entries(value)
        .filter(([, nested]) => nested !== null && nested !== undefined && nested !== "")
        .map(([key, nested]) => `${key}: ${formatAuditValue(nested)}`)
        .join(", ");
    }
    return String(value);
  };

  const formatAuditChange = (details) => {
    const before = details?.before;
    const after = details?.after;

    if (before === undefined && after === undefined) return "—";
    if (before === undefined || after === undefined) return `${formatAuditValue(before ?? "—")} → ${formatAuditValue(after ?? "—")}`;
    if (typeof before !== "object" || typeof after !== "object" || before === null || after === null || Array.isArray(before) || Array.isArray(after)) {
      return `${formatAuditValue(before)} → ${formatAuditValue(after)}`;
    }

    const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
    const diffs = [...keys]
      .map((key) => {
        const oldValue = before[key];
        const newValue = after[key];
        if (oldValue === newValue) return null;
        return `${key}: ${formatAuditValue(oldValue)} → ${formatAuditValue(newValue)}`;
      })
      .filter(Boolean);

    return diffs.length ? diffs.join("; ") : `${formatAuditValue(before)} → ${formatAuditValue(after)}`;
  };

  const exportCsv = () => {
    const escape = (value) => `"${String(value ?? "").replaceAll('"', '""')}"`;
    const rows = [["When", "User", "Email", "Barangay", "Role", "Action", "Target", "Before", "After", "IP"], ...logs.map((log) => {
      const details = parseDetails(log);
      return [new Date(log.created_at).toLocaleString(), log.actor_name, log.actor_email, log.actor_barangay, log.actor_role, log.action, `${log.resource_type || ""} ${log.resource_id || ""}`, formatAuditValue(details?.before), formatAuditValue(details?.after), log.ip_address];
    })];
    const blob = new Blob([rows.map((row) => row.map(escape).join(",")).join("\n")], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob); const link = document.createElement("a"); link.href = url; link.download = "infratrack-audit-logs.csv"; link.click(); URL.revokeObjectURL(url);
  };

  const printLogs = () => {
    const rows = logs.map((log) => { const details = parseDetails(log); const beforeAfter = formatAuditChange(details); return `<tr><td>${new Date(log.created_at).toLocaleString()}</td><td>${log.actor_name || ""}</td><td>${log.actor_barangay || ""}</td><td>${log.action.replaceAll("_", " ")}</td><td>${beforeAfter}</td></tr>`; }).join("");
    const printWindow = window.open("", "_blank");
    if (!printWindow) return;
    printWindow.document.write(`<title>InfraTrack Audit Logs</title><style>body{font:12px Arial;padding:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;text-align:left}</style><h1>InfraTrack Audit Logs</h1><table><thead><tr><th>When</th><th>User</th><th>Barangay</th><th>Action</th><th>Before → After</th></tr></thead><tbody>${rows}</tbody></table>`);
    printWindow.document.close(); printWindow.print();
  };

  const toggle = async (key) => {
    if (!canManageSettings || !settingsLoaded || saving) return;
    const previousValue = settings[key];
    const nextValue = !previousValue;
    setSettings((current) => ({ ...current, [key]: nextValue }));
    setSaving(true);
    setSettingsError("");
    setNotificationSaveStatus("Saving notification preferences…");
    try {
      const response = await apiFetch("/settings", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ settings: { [key]: nextValue } }),
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || "Could not save notification preferences");
      }
      setSettings((current) => ({
        ...current,
        [key]: data.settings?.[key] ?? nextValue,
      }));
      setNotificationSaveStatus("Notification preferences saved.");
    } catch (error) {
      setSettings((current) => ({ ...current, [key]: previousValue }));
      setSettingsError(error.message);
      setNotificationSaveStatus("Could not save. The previous setting was restored.");
    } finally {
      setSaving(false);
    }
  };

  const updateEscalationHours = (key, value) => {
    setSettings((current) => ({
      ...current,
      [key]: value === "" ? "" : Number(value),
    }));
    setSaved(false);
    setSettingsDirty(true);
    setSettingsError("");
  };

  const updateAppearance = (key, value, transitionOrigin = null) => {
    const next = { ...appearance, [key]: value };
    saveAppearance(
      next,
      localStorage,
      document.documentElement,
      window.matchMedia("(prefers-color-scheme: dark)").matches,
      true,
      transitionOrigin,
    );
    setAppearance(next);
  };

  const resetAppearance = () => {
    const next = saveAppearance(
      DEFAULT_APPEARANCE,
      localStorage,
      document.documentElement,
      window.matchMedia("(prefers-color-scheme: dark)").matches,
      true,
    );
    setAppearance(next);
  };

  const saveSettings = async () => {
    if (!canManageSettings) return;
    setSaving(true);
    setSettingsError("");
    try {
      const response = await apiFetch(`/settings`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: user?.id, settings }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not save system settings");
      setSettings((current) => ({ ...current, ...data.settings }));
      setSaved(true);
      setSettingsDirty(false);
    } catch (error) {
      setSettingsError(error.message);
    } finally {
      setSaving(false);
    }
  };

  const changePassword = async (event) => {
    event.preventDefault();
    setPasswordMessage("");
    if (passwords.next !== passwords.confirm) {
      setPasswordMessage("New passwords do not match.");
      return;
    }
    try {
      const response = await apiFetch(`/account/password`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: user?.id, currentPassword: passwords.current, newPassword: passwords.next }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not change password");
      setPasswords({ current: "", next: "", confirm: "" });
      setPasswordMessage(data.emailNotification?.sent
        ? "Password changed successfully. A security alert was emailed to your account."
        : data.emailNotification?.configured
          ? "Password changed successfully, but the security email could not be sent. Please contact your administrator."
          : "Password changed successfully. Email alerts are not configured yet.");
    } catch (error) {
      setPasswordMessage(error.message);
    }
  };

  const downloadExport = async (type) => {
    setDataMessage("");
    const response = await apiFetch(`/admin/export/${type}`);
    if (!response.ok) { const data = await response.json(); setDataMessage(data.error || "Could not export data"); return; }
    const blob = await response.blob();
    const url = URL.createObjectURL(blob); const link = document.createElement("a"); link.href = url; link.download = `infratrack-${type}.csv`; link.click(); URL.revokeObjectURL(url);
    setDataMessage(`${type === "issues" ? "Issue" : "User"} export downloaded.`);
  };

  const createBackup = async () => {
    if (backupPending) return;
    setBackupPending(true);
    setDataMessage("Creating database backup…");
    try {
      const response = await apiFetch("/admin/backup", { method: "POST" });
      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || "Backup failed");
      }
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "infratrack-backup.sql";
      link.click();
      URL.revokeObjectURL(url);
      setDataMessage("Database backup downloaded successfully.");
    } catch (error) {
      setDataMessage(
        `Backup failed: ${error instanceof Error ? error.message : "Could not connect to the API"}`,
      );
    } finally {
      setBackupPending(false);
    }
  };

  const createTeam = async (event) => {
    event.preventDefault();
    const response = await apiFetch("/teams", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(teamForm) });
    const data = await response.json();
    if (!response.ok) { setDataMessage(data.error || "Could not create team"); return; }
    setTeamForm({ name: "", department: "", contactPhone: "" });
    setTeams((current) => [...current, data.team]);
  };

  useEffect(() => {
    if (!logsOnly) apiFetch("/teams").then((response) => response.json()).then((data) => setTeams(data.teams ?? [])).catch(() => {});
  }, [logsOnly]);

  return (
    <div className="settings-page">
      {!logsOnly && <div className="settings-header">
        <div>
          <h2>{isBarangayStaff ? "Account settings" : "System settings"}</h2>
          <p>{isBarangayStaff ? "Review your assigned barangay and secure your account." : "Manage dashboard behavior and notification preferences."}</p>
        </div>
        {canManageSettings && <button type="button" className="primary-button settings-save-button" onClick={saveSettings} disabled={saving || !settingsLoaded || !settingsDirty}>
          {saving ? "Saving…" : saved ? "Saved" : settingsDirty ? "Save changes" : "Settings saved"}
        </button>}
      </div>}

      {settingsError && !logsOnly && canManageSettings && <p className="settings-error" role="alert">{settingsError}</p>}

      {!logsOnly && <div className={`settings-grid ${isBarangayStaff ? "account-settings-grid" : ""}`}>
        <section className="card settings-card appearance-settings-card" aria-labelledby="appearance-title">
          <div className="card-head">
            <div>
              <h3 id="appearance-title">Appearance</h3>
              <p>Personalize how InfraTrack looks on this device.</p>
            </div>
            <button
              className="appearance-reset-button"
              type="button"
              onClick={resetAppearance}
              disabled={
                JSON.stringify(appearance) === JSON.stringify(DEFAULT_APPEARANCE)
              }
            >
              <RotateCcw size={14} aria-hidden="true" />
              Reset to defaults
            </button>
          </div>
          <div className="appearance-section">
            <h4><Sun size={15} aria-hidden="true" /> Theme</h4>
            <div className="appearance-theme-options" role="group" aria-label="Color theme">
              {[
                { value: "light", label: "Light", Icon: Sun },
                { value: "dark", label: "Dark", Icon: Moon },
                { value: "system", label: "System", Icon: Monitor },
              ].map(({ value, label, Icon }) => (
                <button
                  key={value}
                  type="button"
                  className={`appearance-theme-option ${appearance.theme === value ? "selected" : ""}`}
                  aria-pressed={appearance.theme === value}
                  onClick={(event) =>
                    updateAppearance("theme", value, event.currentTarget)
                  }
                >
                  <span className={`appearance-preview appearance-preview-${value}`} aria-hidden="true">
                    <i /><i /><i />
                  </span>
                  <span className="appearance-choice-label"><Icon size={14} /> {label}</span>
                  <small>
                    {value === "light" ? "Bright and clear" : value === "dark" ? "Comfortable in low light" : "Follows your device"}
                  </small>
                </button>
              ))}
            </div>
          </div>
          <div className="appearance-section">
            <h4><Palette size={15} aria-hidden="true" /> Accent color</h4>
            <div className="appearance-accent-options" role="group" aria-label="Accent color">
              {[
                ["teal", "InfraTrack"],
                ["blue", "Blue"],
                ["emerald", "Emerald"],
                ["violet", "Violet"],
                ["amber", "Amber"],
                ["rose", "Rose"],
              ].map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  className={`appearance-accent-option ${appearance.accent === value ? "selected" : ""}`}
                  aria-label={`${label} accent`}
                  aria-pressed={appearance.accent === value}
                  onClick={() => updateAppearance("accent", value)}
                >
                  <span style={{ "--swatch-color": ACCENT_COLORS[value].value }}>
                    {appearance.accent === value && <Check size={15} aria-hidden="true" />}
                  </span>
                  <small>{label}</small>
                </button>
              ))}
            </div>
          </div>
          <div className="appearance-section">
            <h4><Type size={15} aria-hidden="true" /> Typeface</h4>
            <div className="appearance-typeface-options" role="group" aria-label="Typeface">
              {[
                ["inter", "Inter", "The InfraTrack default"],
                ["system", "System UI", "Native to your device"],
                ["arial", "Arial", "A familiar sans serif"],
                ["roboto", "Roboto", "Clean and easy to scan"],
                ["lato", "Lato", "Warm and approachable"],
                ["open-sans", "Open Sans", "Clear and highly readable"],
                ["poppins", "Poppins", "Geometric and modern"],
                ["nunito", "Nunito", "Friendly and rounded"],
              ].map(([value, label, description]) => (
                <button
                  key={value}
                  type="button"
                  className={`appearance-typeface-option typeface-${value} ${appearance.typeface === value ? "selected" : ""}`}
                  aria-pressed={appearance.typeface === value}
                  onClick={() => updateAppearance("typeface", value)}
                >
                  <strong>Aa</strong>
                  <span><b>{label}</b><small>{description}</small></span>
                </button>
              ))}
            </div>
          </div>
          <div className="appearance-section">
            <h4><Type size={15} aria-hidden="true" /> Text size</h4>
            <div className="appearance-detail-options" role="group" aria-label="Text size">
              {[
                ["compact", "Compact", "More content, less space"],
                ["regular", "Regular", "The balanced default"],
                ["large", "Large", "Easier to read"],
              ].map(([value, label, description]) => (
                <button
                  key={value}
                  type="button"
                  className={`appearance-detail-option appearance-text-size-option text-size-${value} ${appearance.textSize === value ? "selected" : ""}`}
                  aria-pressed={appearance.textSize === value}
                  onClick={() => updateAppearance("textSize", value)}
                >
                  <span className="appearance-text-sample" aria-hidden="true">
                    <strong>Aa</strong>
                    <small>The quick brown fox jumps</small>
                  </span>
                  <span className="appearance-detail-label">{label}</span>
                  <small>{description}</small>
                </button>
              ))}
            </div>
          </div>
          <div className="appearance-section">
            <h4><span className="appearance-corners-icon" aria-hidden="true" /> Corners</h4>
            <div className="appearance-detail-options" role="group" aria-label="Corner style">
              {[
                ["square", "Square", "Crisp, minimal edges"],
                ["rounded", "Rounded", "The balanced default"],
                ["soft", "Soft", "A gentler, softer feel"],
              ].map(([value, label, description]) => (
                <button
                  key={value}
                  type="button"
                  className={`appearance-detail-option appearance-corner-option corner-${value} ${appearance.corners === value ? "selected" : ""}`}
                  aria-pressed={appearance.corners === value}
                  onClick={() => updateAppearance("corners", value)}
                >
                  <span className="appearance-corner-sample" aria-hidden="true" />
                  <span className="appearance-detail-label">{label}</span>
                  <small>{description}</small>
                </button>
              ))}
            </div>
          </div>
          <div className="appearance-section">
            <h4><Contrast size={15} aria-hidden="true" /> Contrast</h4>
            <div className="appearance-contrast-control">
              <span>
                <strong>High contrast</strong>
                <small>Strengthen text and control boundaries for readability.</small>
              </span>
              <button
                className={`appearance-contrast-toggle ${appearance.highContrast ? "on" : ""}`}
                type="button"
                role="switch"
                aria-label="High contrast"
                aria-checked={appearance.highContrast}
                onClick={() =>
                  updateAppearance("highContrast", !appearance.highContrast)
                }
              >
                <span />
              </button>
            </div>
          </div>
        </section>
        {!isBarangayStaff && <>
        <article className="card settings-card">
          <div className="card-head">
            <h3>Notifications</h3>
          </div>

          <div className="setting-row">
            <div>
              <strong>New report alerts</strong>
              <small>Notify LGU administrators when a resident submits a report.</small>
            </div>
            <button type="button" role="switch" aria-label="New report alerts" aria-checked={settings.newReportAlerts} disabled={saving || !settingsLoaded} className={`toggle ${settings.newReportAlerts ? "on" : ""}`} onClick={() => toggle("newReportAlerts")}>
              <span />
            </button>
          </div>

          <div className="setting-row">
            <div>
              <strong>Priority escalation alerts</strong>
              <small>Notify the office when an overdue issue moves to a higher severity.</small>
            </div>
            <button type="button" role="switch" aria-label="Priority escalation alerts" aria-checked={settings.reportAlerts} disabled={saving || !settingsLoaded} className={`toggle ${settings.reportAlerts ? "on" : ""}`} onClick={() => toggle("reportAlerts")}>
              <span />
            </button>
          </div>

          <div className="setting-row">
            <div>
              <strong>Possible duplicate alerts</strong>
              <small>Notify the office when a report may duplicate an existing issue.</small>
            </div>
            <button type="button" role="switch" aria-label="Possible duplicate alerts" aria-checked={settings.duplicateAlerts} disabled={saving || !settingsLoaded} className={`toggle ${settings.duplicateAlerts ? "on" : ""}`} onClick={() => toggle("duplicateAlerts")}>
              <span />
            </button>
          </div>
          <p className="settings-card-description" role="status" aria-live="polite">
            {notificationSaveStatus || "Changes save automatically when you switch an alert."}
          </p>
        </article>

        <article className="card settings-card">
          <div className="card-head">
            <h3>Issue workflow</h3>
          </div>
          <p className="settings-card-description">
            Automatically raise unresolved report severity after these age limits. Changes apply during the next report update or five-minute escalation check.
          </p>
          {[
            ["lowSeverityEscalationHours", "Low to Medium"],
            ["mediumSeverityEscalationHours", "Medium to High"],
            ["highSeverityEscalationHours", "High to Critical"],
          ].map(([key, label]) => (
            <label className="workflow-threshold-row" key={key}>
              <span>{label}</span>
              <span className="workflow-threshold-input">
                <input
                  aria-label={`${label} escalation time in hours`}
                  type="number"
                  min="1"
                  max="8760"
                  step="1"
                  value={settings[key]}
                  disabled={saving || !settingsLoaded}
                  onChange={(event) => updateEscalationHours(key, event.target.value)}
                  required
                />
                <small>hours</small>
              </span>
            </label>
          ))}
        </article>

        </>}
        <article className="card settings-card">
          <div className="card-head">
            <h3>Account & security</h3>
          </div>
          <p style={{ color: "#71808a", marginTop: 0 }}>Change the password used for this account.</p>
          <form onSubmit={changePassword}>
            <label className="visually-hidden" htmlFor="settings-current-password">Current password</label>
            <input id="settings-current-password" className="settings-input" type="password" autoComplete="current-password" placeholder="Current password" value={passwords.current} onChange={(event) => setPasswords((current) => ({ ...current, current: event.target.value }))} required />
            <label className="visually-hidden" htmlFor="settings-new-password">New password</label>
            <input id="settings-new-password" className="settings-input" type="password" autoComplete="new-password" placeholder="New password (8+ characters)" value={passwords.next} onChange={(event) => setPasswords((current) => ({ ...current, next: event.target.value }))} minLength={8} required />
            <label className="visually-hidden" htmlFor="settings-confirm-password">Confirm new password</label>
            <input id="settings-confirm-password" className="settings-input" type="password" autoComplete="new-password" placeholder="Confirm new password" value={passwords.confirm} onChange={(event) => setPasswords((current) => ({ ...current, confirm: event.target.value }))} minLength={8} required />
            <button type="submit" className="secondary-button">Change password</button>
          </form>
          {passwordMessage && <p role="status" style={{ color: passwordMessage.includes("successfully") && !passwordMessage.includes("but") ? "#1b8a83" : "#9f351e" }}>{passwordMessage}</p>}
        </article>

        <article className="card settings-card">
          <div className="card-head">
            <h3>{user?.role === "barangay_staff" ? "Barangay profile" : "Administrator profile"}</h3>
          </div>
          <div className="setting-row"><div><strong>{user?.name || "—"}</strong><small>Account name</small></div></div>
          <div className="setting-row"><div><strong>{user?.email || "—"}</strong><small>Email address</small></div></div>
          <div className="setting-row"><div><strong>{user?.barangay || "Mati City"}</strong><small>{user?.role === "barangay_staff" ? "Assigned barangay" : "Coverage"}</small></div></div>
        </article>

        <article className="card settings-card data-management-card">
          <div className="card-head"><h3>Data management</h3></div>
          <p style={{ color: "#71808a", marginTop: 0 }}>{isBarangayStaff ? `Export operational data for ${user?.barangay || "your barangay"}.` : "Export operational data or create a database backup. Backups are also scheduled daily on the server."}</p>
          <div className="data-actions">
            <button type="button" className="secondary-button" onClick={() => downloadExport("issues")}>Export issues CSV</button>
            <button type="button" className="secondary-button" onClick={() => downloadExport("users")}>{isBarangayStaff ? "Export residents CSV" : "Export users CSV"}</button>
            {["lgu", "admin"].includes(user?.role) && <button type="button" className="primary-button" onClick={createBackup} disabled={backupPending}>{backupPending ? "Creating backup…" : "Create LGU backup"}</button>}
          </div>
          {dataMessage && <p role="status" style={{ color: dataMessage.includes("failed") || dataMessage.includes("Could") ? "#9f351e" : "#1b8a83" }}>{dataMessage}</p>}
          {["lgu", "admin"].includes(user?.role) && <details className="restore-instructions"><summary>Restore instructions</summary><p>Stop the InfraTrack API, create a safety copy of the database, then import the downloaded <code>.sql</code> file into the <code>infratrack</code> MySQL database using phpMyAdmin or the MySQL command line. Restart the API and verify the health endpoint.</p></details>}
        </article>
        <article className="card settings-card data-management-card">
          <div className="card-head"><h3>{isBarangayStaff ? "Available response teams" : "Teams & assignments"}</h3></div>
          <p style={{ color: "#71808a", marginTop: 0 }}>{isBarangayStaff ? "Teams available for reports in your assigned barangay." : "Manage the teams available for issue assignment."}</p>
          {["lgu", "admin"].includes(user?.role) && <form className="team-form" onSubmit={createTeam}><input aria-label="Team name" placeholder="Team name" value={teamForm.name} onChange={(event) => setTeamForm({ ...teamForm, name: event.target.value })} required /><input aria-label="Department" placeholder="Department" value={teamForm.department} onChange={(event) => setTeamForm({ ...teamForm, department: event.target.value })} /><input aria-label="Contact phone" placeholder="Contact phone" value={teamForm.contactPhone} onChange={(event) => setTeamForm({ ...teamForm, contactPhone: event.target.value })} /><button className="secondary-button" type="submit">Add team</button></form>}
          <div className="team-list">{teams.map((team) => <span key={team.id} className="team-chip"><strong>{team.name}</strong>{team.department && ` · ${team.department}`}</span>)}</div>
        </article>
      </div>}

      {logsOnly && <article className="card settings-card" style={{ marginTop: 24 }}>
        <div className="card-head">
          <div>
          <h3>{isBarangayStaff ? "Barangay activity logs" : "Access & activity logs"}</h3>
          <p style={{ margin: "6px 0 0", color: "#71808a" }}>{isBarangayStaff ? `Review actions recorded for ${user?.barangay || "your barangay"}.` : "See who accessed the system and which administrative actions were performed."}</p>
          </div>
          <div className="audit-export-actions">
            <button type="button" className="secondary-button" onClick={exportCsv}>Export CSV</button>
            <button type="button" className="secondary-button" onClick={printLogs}>Print / PDF</button>
          </div>
        </div>
        <div className="audit-filters">
          <input placeholder="Search user or email" value={auditFilters.user} onChange={(event) => updateAuditFilter("user", event.target.value)} />
          <select value={auditFilters.action} onChange={(event) => updateAuditFilter("action", event.target.value)}>
            <option value="">All actions</option><option value="login">Login</option><option value="issue_accepted">Accepted</option><option value="issue_rejected">Rejected</option><option value="issue_assigned">Assigned</option><option value="issue_resolved">Resolved</option><option value="issue_archived">Archived</option><option value="staff_created">Staff created</option><option value="staff_disabled">Staff disabled</option>
          </select>
          {user?.role !== "barangay_staff" && <input placeholder="Barangay" value={auditFilters.barangay} onChange={(event) => updateAuditFilter("barangay", event.target.value)} />}
          <label style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, fontWeight: 700, color: "#153f52" }}>
            <span>From</span>
            <input type="date" aria-label="Filter audit logs from date" value={auditFilters.from} onChange={(event) => updateAuditFilter("from", event.target.value)} />
          </label>
          <label style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, fontWeight: 700, color: "#153f52" }}>
            <span>To</span>
            <input type="date" aria-label="Filter audit logs to date" value={auditFilters.to} onChange={(event) => updateAuditFilter("to", event.target.value)} />
          </label>
        </div>
        {logsError && <p role="alert" style={{ color: "#9f351e" }}>{logsError}</p>}
        {auditLoading && <p role="status" style={{ color: "#71808a" }}>Loading activity logs…</p>}
        {!auditLoading && !logsError && !logs.length && <p style={{ color: "#71808a" }}>No activity has been recorded yet.</p>}
        {!auditLoading && !!logs.length && (
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", minWidth: 720 }}>
              <thead>
                <tr style={{ textAlign: "left", color: "#71808a", fontSize: 12 }}>
                  <th style={{ padding: "10px 8px" }}>When</th>
                  <th style={{ padding: "10px 8px" }}>User</th>
                  <th style={{ padding: "10px 8px" }}>Role</th>
                  <th style={{ padding: "10px 8px" }}>Action</th>
                  <th style={{ padding: "10px 8px" }}>Target</th>
                  <th style={{ padding: "10px 8px" }}>Before → After</th>
                  <th style={{ padding: "10px 8px" }}>IP address</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id} style={{ borderTop: "1px solid #e8eceb" }}>
                    {(() => { const details = parseDetails(log); return <>
                    <td style={{ padding: "12px 8px", whiteSpace: "nowrap" }}>{new Date(log.created_at).toLocaleString()}</td>
                    <td style={{ padding: "12px 8px" }}><strong>{log.actor_name || log.actor_email || "Unknown user"}</strong><br /><small>{log.actor_email}</small></td>
                    <td style={{ padding: "12px 8px" }}>{log.actor_role || "—"}</td>
                    <td style={{ padding: "12px 8px" }}>{log.action.replaceAll("_", " ")}</td>
                    <td style={{ padding: "12px 8px" }}>{log.resource_type ? `${log.resource_type}${log.resource_id ? ` #${log.resource_id}` : ""}` : "—"}</td>
                    <td style={{ padding: "12px 8px", fontSize: 11 }}>{formatAuditChange(details)}</td>
                    <td style={{ padding: "12px 8px" }}>
                      {isPublicIpAddress(log.ip_address) ? (
                        <button type="button" className="audit-ip-link" onClick={() => setSelectedIpLog(log)}>
                          <MapPin size={13} /> {log.ip_address}
                        </button>
                      ) : (
                        log.ip_address === "::1" ? "Localhost (::1)" : log.ip_address || "—"
                      )}
                    </td>
                    </>; })()}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!logsError && auditTotal > 0 && (
          <div className="queue-footer" style={{ paddingTop: 10, paddingBottom: 4 }}>
            <span>Showing {auditStart}–{auditEnd} of {auditTotal} logs</span>
            <div className="pagination">
              <button
                type="button"
                aria-label="Previous page"
                disabled={auditPage === 0 || auditLoading}
                onClick={() => setAuditPage((page) => Math.max(0, page - 1))}
              >
                ‹
              </button>
              <span aria-live="polite" style={{ alignSelf: "center", minWidth: 72, textAlign: "center" }}>
                Page {auditPage + 1} of {auditPageCount}
              </span>
              <button
                type="button"
                aria-label="Next page"
                disabled={auditPage + 1 >= auditPageCount || auditLoading}
                onClick={() => setAuditPage((page) => Math.min(auditPageCount - 1, page + 1))}
              >
                ›
              </button>
            </div>
          </div>
        )}
      </article>}
      {selectedIpLog && <IpLocationModal log={selectedIpLog} onClose={() => setSelectedIpLog(null)} />}
    </div>
  );
}

function IpLocationModal({ log, onClose }) {
  const ip = log.ip_address;
  const [location, setLocation] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [mapLayer, setMapLayer] = useState("street");

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = previousOverflow; };
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError("");
    setLocation(null);
    apiFetch(`/ip-location/${encodeURIComponent(ip)}`, { signal: controller.signal })
      .then(async (response) => {
        const data = await response.json();
        if (!response.ok || data.success === false) throw new Error(data.message || "Could not locate this IP address.");
        return data;
      })
      .then(setLocation)
      .catch((requestError) => {
        if (requestError.name !== "AbortError") setError(requestError.message || "Could not locate this IP address.");
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, [ip]);

  const coordinates = location?.latitude && location?.longitude
    ? [Number(location.latitude), Number(location.longitude)]
    : null;
  const mapCoordinates = coordinates;
  const mapUrl = mapCoordinates ? `https://www.openstreetmap.org/?mlat=${mapCoordinates[0]}&mlon=${mapCoordinates[1]}#map=15/${mapCoordinates[0]}/${mapCoordinates[1]}` : "";
  const actorBarangay = String(log.actor_barangay || "").trim();
  const operatingArea = actorBarangay && !/^mati city$/i.test(actorBarangay)
    ? `${actorBarangay}, Mati City, Davao Oriental`
    : "Mati City, Davao Oriental";

  return createPortal(
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal ip-location-modal" role="dialog" aria-modal="true" aria-labelledby="ip-location-title" onClick={(event) => event.stopPropagation()}>
        <button type="button" className="modal-close" aria-label="Close IP location" onClick={onClose}><X size={18} /></button>
        <div className="ip-location-heading">
          <div>
            <span className="eyebrow">Audit log location</span>
            <h2 id="ip-location-title">Network location: {ip}</h2>
          </div>
          {mapCoordinates && <a className="secondary-button ip-map-link" href={mapUrl} target="_blank" rel="noreferrer"><ExternalLink size={14} /> Open in Maps</a>}
        </div>
        {loading && <p className="ip-location-state">Loading approximate location…</p>}
        {error && <p className="ip-location-state error" role="alert">{error}</p>}
        {!loading && !error && !coordinates && <p className="ip-location-state">No public network location is available for this address.</p>}
        {coordinates && location && (
          <>
            <div className="ip-location-notice">
              <strong>Recorded IP verified</strong>
              <span>This map is an automatic network estimate for the exact IP saved in this audit record. IP databases cannot identify the visitor’s exact physical location; mobile and shared networks may resolve to another city.</span>
            </div>
            <div className="ip-location-map">
              <MapContainer center={mapCoordinates} zoom={11} scrollWheelZoom className="leaflet-map">
                {mapLayer === "street" ? (
                  <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
                ) : (
                  <TileLayer attribution="Tiles &copy; Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community" url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}" />
                )}
                {coordinates && <CircleMarker center={coordinates} radius={10} pathOptions={{ color: "#c1592b", fillColor: "#c1592b", fillOpacity: 0.8 }} />}
              </MapContainer>
              <div className="ip-map-layer-switcher" role="group" aria-label="Location map layer">
                <button type="button" className={mapLayer === "street" ? "active" : ""} onClick={() => setMapLayer("street")}>Street</button>
                <button type="button" className={mapLayer === "satellite" ? "active" : ""} onClick={() => setMapLayer("satellite")}>Satellite</button>
              </div>
            </div>
            <div className="ip-location-details">
              <strong>Network estimate: {[location.city, location.region, location.country].filter(Boolean).join(", ") || "Unavailable"}</strong>
              <span>{location.isp || location.org || "Network details unavailable"}</span>
              <span>Recorded IP: {location.ip || ip}</span>
              <span>InfraTrack operating area: {operatingArea}</span>
            </div>
          </>
        )}
      </div>
    </div>,
    document.body,
  );
}
