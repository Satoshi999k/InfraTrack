import { useEffect, useState } from "react";
import { API_BASE, apiFetch } from "../api";

const defaultSettings = {
  liveNotifications: true,
  emailDigest: false,
  autoAssign: true,
  requireApproval: true,
  reportAlerts: true,
  publicAdvisoryAlerts: false,
};

export default function SettingsPage({ user, logsOnly = false }) {
  const [settings, setSettings] = useState(defaultSettings);
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const [settingsError, setSettingsError] = useState("");
  const [passwords, setPasswords] = useState({ current: "", next: "", confirm: "" });
  const [passwordMessage, setPasswordMessage] = useState("");
  const [dataMessage, setDataMessage] = useState("");
  const [teams, setTeams] = useState([]);
  const [teamForm, setTeamForm] = useState({ name: "", department: "", contactPhone: "" });
  const [logs, setLogs] = useState([]);
  const [logsError, setLogsError] = useState("");
  const [auditFilters, setAuditFilters] = useState({ user: "", action: "", barangay: "", from: "", to: "" });

  useEffect(() => {
    if (!user?.id || logsOnly) return;
    try {
      const stored = JSON.parse(localStorage.getItem("infratrack.adminSettings") || "null");
      if (stored) {
        setSettings({ ...defaultSettings, ...stored });
      }
    } catch {
      // Ignore malformed saved data and keep defaults.
    }
    apiFetch(`/settings?userId=${encodeURIComponent(user.id)}`)
      .then(async (response) => {
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || "Could not load system settings");
        setSettings((current) => ({ ...current, ...data.settings }));
      })
      .catch((error) => setSettingsError(error.message));
  }, [user?.id, logsOnly]);

  const loadLogs = () => {
    if (!user?.id || !["lgu", "admin", "barangay_staff"].includes(user.role)) return;
    const query = new URLSearchParams({ adminId: user.id, ...Object.fromEntries(Object.entries(auditFilters).filter(([, value]) => value)) });
    apiFetch(`/audit-logs?${query.toString()}`)
      .then(async (response) => {
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || "Could not load audit logs");
        setLogs(data.logs ?? []);
      })
      .catch((error) => setLogsError(error.message));
  };

  useEffect(() => { loadLogs(); }, [user, auditFilters]);

  const parseDetails = (log) => {
    try { return log.details ? JSON.parse(log.details) : null; } catch { return null; }
  };

  const exportCsv = () => {
    const escape = (value) => `"${String(value ?? "").replaceAll('"', '""')}"`;
    const rows = [["When", "User", "Email", "Barangay", "Role", "Action", "Target", "Before", "After", "IP"], ...logs.map((log) => {
      const details = parseDetails(log);
      return [new Date(log.created_at).toLocaleString(), log.actor_name, log.actor_email, log.actor_barangay, log.actor_role, log.action, `${log.resource_type || ""} ${log.resource_id || ""}`, JSON.stringify(details?.before || ""), JSON.stringify(details?.after || ""), log.ip_address];
    })];
    const blob = new Blob([rows.map((row) => row.map(escape).join(",")).join("\n")], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob); const link = document.createElement("a"); link.href = url; link.download = "infratrack-audit-logs.csv"; link.click(); URL.revokeObjectURL(url);
  };

  const printLogs = () => {
    const rows = logs.map((log) => { const details = parseDetails(log); return `<tr><td>${new Date(log.created_at).toLocaleString()}</td><td>${log.actor_name || ""}</td><td>${log.actor_barangay || ""}</td><td>${log.action.replaceAll("_", " ")}</td><td>${JSON.stringify(details?.before || "")}</td><td>${JSON.stringify(details?.after || "")}</td></tr>`; }).join("");
    const printWindow = window.open("", "_blank");
    if (!printWindow) return;
    printWindow.document.write(`<title>InfraTrack Audit Logs</title><style>body{font:12px Arial;padding:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;text-align:left}</style><h1>InfraTrack Audit Logs</h1><table><thead><tr><th>When</th><th>User</th><th>Barangay</th><th>Action</th><th>Before</th><th>After</th></tr></thead><tbody>${rows}</tbody></table>`);
    printWindow.document.close(); printWindow.print();
  };

  const toggle = (key) => {
    setSettings((current) => ({ ...current, [key]: !current[key] }));
    setSaved(false);
  };

  const saveSettings = async () => {
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
    setDataMessage("Creating database backup…");
    const response = await apiFetch("/admin/backup", { method: "POST" });
    if (!response.ok) { const data = await response.json(); setDataMessage(data.error || "Backup failed"); return; }
    const blob = await response.blob();
    const url = URL.createObjectURL(blob); const link = document.createElement("a"); link.href = url; link.download = "infratrack-backup.sql"; link.click(); URL.revokeObjectURL(url);
    setDataMessage("Database backup downloaded successfully.");
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
          <h2>System settings</h2>
          <p>Manage dashboard behavior and notification preferences.</p>
        </div>
        <button type="button" className="primary-button" onClick={saveSettings} disabled={saving}>
          {saving ? "Saving…" : saved ? "Saved" : "Save changes"}
        </button>
      </div>}

      {settingsError && !logsOnly && <p role="alert" style={{ color: "#9f351e", marginBottom: 16 }}>{settingsError}</p>}

      {!logsOnly && <div className="settings-grid">
        <article className="card settings-card">
          <div className="card-head">
            <h3>Notifications</h3>
          </div>

          <div className="setting-row">
            <div>
              <strong>Live notifications</strong>
              <small>Show new issue alerts in real time.</small>
            </div>
            <button type="button" className={`toggle ${settings.liveNotifications ? "on" : ""}`} onClick={() => toggle("liveNotifications")}>
              <span />
            </button>
          </div>

          <div className="setting-row">
            <div>
              <strong>Email digest</strong>
              <small>Send a summary every morning.</small>
            </div>
            <button type="button" className={`toggle ${settings.emailDigest ? "on" : ""}`} onClick={() => toggle("emailDigest")}>
              <span />
            </button>
          </div>

          <div className="setting-row">
            <div>
              <strong>Report alerts</strong>
              <small>Notify the office of critical issues immediately.</small>
            </div>
            <button type="button" className={`toggle ${settings.reportAlerts ? "on" : ""}`} onClick={() => toggle("reportAlerts")}>
              <span />
            </button>
          </div>
        </article>

        <article className="card settings-card">
          <div className="card-head">
            <h3>Operations</h3>
          </div>

          <div className="setting-row">
            <div>
              <strong>Auto-assign high priority issues</strong>
              <small>Assign urgent items to the nearest active crew.</small>
            </div>
            <button type="button" className={`toggle ${settings.autoAssign ? "on" : ""}`} onClick={() => toggle("autoAssign")}>
              <span />
            </button>
          </div>

          <div className="setting-row">
            <div>
              <strong>Require supervisor approval</strong>
              <small>Require validation before closing a case.</small>
            </div>
            <button type="button" className={`toggle ${settings.requireApproval ? "on" : ""}`} onClick={() => toggle("requireApproval")}>
              <span />
            </button>
          </div>

          <div className="setting-row">
            <div>
              <strong>Public advisory alerts</strong>
              <small>Send push notifications for barangay advisories.</small>
            </div>
            <button type="button" className={`toggle ${settings.publicAdvisoryAlerts ? "on" : ""}`} onClick={() => toggle("publicAdvisoryAlerts")}>
              <span />
            </button>
          </div>
        </article>

        <article className="card settings-card">
          <div className="card-head">
            <h3>Account & security</h3>
          </div>
          <p style={{ color: "#71808a", marginTop: 0 }}>Change the password used for this administrator account.</p>
          <form onSubmit={changePassword}>
            <input className="settings-input" type="password" placeholder="Current password" value={passwords.current} onChange={(event) => setPasswords((current) => ({ ...current, current: event.target.value }))} required />
            <input className="settings-input" type="password" placeholder="New password (8+ characters)" value={passwords.next} onChange={(event) => setPasswords((current) => ({ ...current, next: event.target.value }))} minLength={8} required />
            <input className="settings-input" type="password" placeholder="Confirm new password" value={passwords.confirm} onChange={(event) => setPasswords((current) => ({ ...current, confirm: event.target.value }))} minLength={8} required />
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
          <p style={{ color: "#71808a", marginTop: 0 }}>Export operational data or create a database backup. Backups are also scheduled daily on the server.</p>
          <div className="data-actions">
            <button type="button" className="secondary-button" onClick={() => downloadExport("issues")}>Export issues CSV</button>
            <button type="button" className="secondary-button" onClick={() => downloadExport("users")}>Export users CSV</button>
            {["lgu", "admin"].includes(user?.role) && <button type="button" className="primary-button" onClick={createBackup}>Create LGU backup</button>}
          </div>
          {dataMessage && <p role="status" style={{ color: dataMessage.includes("failed") || dataMessage.includes("Could") ? "#9f351e" : "#1b8a83" }}>{dataMessage}</p>}
          {["lgu", "admin"].includes(user?.role) && <details className="restore-instructions"><summary>Restore instructions</summary><p>Stop the InfraTrack API, create a safety copy of the database, then import the downloaded <code>.sql</code> file into the <code>infratrack</code> MySQL database using phpMyAdmin or the MySQL command line. Restart the API and verify the health endpoint.</p></details>}
        </article>
        <article className="card settings-card data-management-card">
          <div className="card-head"><h3>Teams & assignments</h3></div>
          <p style={{ color: "#71808a", marginTop: 0 }}>Manage the teams available for issue assignment.</p>
          {["lgu", "admin"].includes(user?.role) && <form className="team-form" onSubmit={createTeam}><input placeholder="Team name" value={teamForm.name} onChange={(event) => setTeamForm({ ...teamForm, name: event.target.value })} required /><input placeholder="Department" value={teamForm.department} onChange={(event) => setTeamForm({ ...teamForm, department: event.target.value })} /><input placeholder="Contact phone" value={teamForm.contactPhone} onChange={(event) => setTeamForm({ ...teamForm, contactPhone: event.target.value })} /><button className="secondary-button" type="submit">Add team</button></form>}
          <div className="team-list">{teams.map((team) => <span key={team.id} className="team-chip"><strong>{team.name}</strong>{team.department && ` · ${team.department}`}</span>)}</div>
        </article>
      </div>}

      {logsOnly && <article className="card settings-card" style={{ marginTop: 24 }}>
        <div className="card-head">
          <div>
            <h3>Access & activity logs</h3>
            <p style={{ margin: "6px 0 0", color: "#71808a" }}>See who accessed the system and which administrative actions were performed.</p>
          </div>
          <div className="audit-export-actions">
            <button type="button" className="secondary-button" onClick={exportCsv}>Export CSV</button>
            <button type="button" className="secondary-button" onClick={printLogs}>Print / PDF</button>
          </div>
        </div>
        <div className="audit-filters">
          <input placeholder="Search user or email" value={auditFilters.user} onChange={(event) => setAuditFilters({ ...auditFilters, user: event.target.value })} />
          <select value={auditFilters.action} onChange={(event) => setAuditFilters({ ...auditFilters, action: event.target.value })}>
            <option value="">All actions</option><option value="login">Login</option><option value="issue_accepted">Accepted</option><option value="issue_rejected">Rejected</option><option value="issue_assigned">Assigned</option><option value="issue_resolved">Resolved</option><option value="issue_archived">Archived</option><option value="staff_created">Staff created</option><option value="staff_disabled">Staff disabled</option>
          </select>
          {user?.role !== "barangay_staff" && <input placeholder="Barangay" value={auditFilters.barangay} onChange={(event) => setAuditFilters({ ...auditFilters, barangay: event.target.value })} />}
          <label style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, fontWeight: 700, color: "#153f52" }}>
            <span>From</span>
            <input type="date" aria-label="Filter audit logs from date" value={auditFilters.from} onChange={(event) => setAuditFilters({ ...auditFilters, from: event.target.value })} />
          </label>
          <label style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, fontWeight: 700, color: "#153f52" }}>
            <span>To</span>
            <input type="date" aria-label="Filter audit logs to date" value={auditFilters.to} onChange={(event) => setAuditFilters({ ...auditFilters, to: event.target.value })} />
          </label>
        </div>
        {logsError && <p role="alert" style={{ color: "#9f351e" }}>{logsError}</p>}
        {!logsError && !logs.length && <p style={{ color: "#71808a" }}>No activity has been recorded yet.</p>}
        {!!logs.length && (
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
                    <td style={{ padding: "12px 8px", fontSize: 11 }}>{details?.before || details?.after ? `${JSON.stringify(details.before || "")} → ${JSON.stringify(details.after || "")}` : "—"}</td>
                    <td style={{ padding: "12px 8px" }}>{log.ip_address === "::1" ? "Localhost (::1)" : log.ip_address || "—"}</td>
                    </>; })()}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </article>}
    </div>
  );
}
