import { useState } from "react";
import {
  AlertTriangle,
  Ban,
  CalendarDays,
  CheckCircle2,
  Clock3,
  FileText,
  Eye,
  MapPin,
  ShieldAlert,
  ShieldCheck,
  Users,
  X,
} from "lucide-react";

export function Modal({ data, onClose, onSave, onUserSave }) {
  if (data.type === "user") return <UserModal user={data.user} onClose={onClose} onSave={onUserSave} />;
  if (data.type === "walkin") return <WalkInModal onClose={onClose} onSave={onSave} />;
  if (data.type === "help") return <HelpModal onClose={onClose} />;
  return <IssueModal data={data} onClose={onClose} onSave={onSave} />;
}

function HelpModal({ onClose }) {
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal advisory-editor-modal" onClick={(event) => event.stopPropagation()}>
        <button type="button" className="modal-close" onClick={onClose}><X size={18} /></button>
        <div className="advisory-edit-header">
          <h2>Need help?</h2>
          <p>Use the admin dashboard to review reports, assign field teams, and monitor infrastructure issues in Mati City.</p>
        </div>

        <div style={{ display: "grid", gap: 12, marginTop: 12 }}>
          <div className="modal-section">
            <h3>Quick actions</h3>
            <ul style={{ margin: 0, paddingLeft: 18, color: "#335f68", lineHeight: 1.7 }}>
              <li>Review incoming reports in the issue queue.</li>
              <li>Log walk-in reports from the top-right action button.</li>
              <li>Open the map to inspect location-based infrastructure issues.</li>
              <li>Use analytics to monitor trends and resident ratings.</li>
            </ul>
          </div>
        </div>

        <div className="advisory-edit-actions" style={{ marginTop: 18 }}>
          <button type="button" className="primary-button" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

function WalkInModal({ onClose, onSave }) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("Roads");
  const [location, setLocation] = useState("Mati City");
  const [severity, setSeverity] = useState("Medium");
  const [saving, setSaving] = useState(false);

  const submit = async (event) => {
    event.preventDefault();
    if (!title.trim() || !description.trim() || !location.trim()) return;
    setSaving(true);
    try {
      await onSave({ title, description, category, location, severity });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <form className="modal advisory-editor-modal" onClick={(event) => event.stopPropagation()} onSubmit={submit}>
        <button type="button" className="modal-close" onClick={onClose}><X size={18} /></button>
        <div className="advisory-edit-header">
          <h2>Log a walk-in report</h2>
          <p>Create a report for a resident who visited the office.</p>
        </div>
        <label>Issue title</label>
        <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="e.g. Broken streetlight near city hall" autoFocus />
        <label>Category</label>
        <select value={category} onChange={(event) => setCategory(event.target.value)}>
          <option>Roads</option><option>Water</option><option>Drainage</option><option>Lighting</option><option>Debris</option>
        </select>
        <label>Location or barangay</label>
        <input value={location} onChange={(event) => setLocation(event.target.value)} placeholder="e.g. Brgy. Central" />
        <label>Severity</label>
        <select value={severity} onChange={(event) => setSeverity(event.target.value)}>
          <option>Low</option><option>Medium</option><option>High</option><option>Critical</option>
        </select>
        <label>Description</label>
        <textarea value={description} onChange={(event) => setDescription(event.target.value)} placeholder="Describe the issue and safety concern…" />
        <div className="advisory-edit-actions">
          <button type="button" className="secondary-button" onClick={onClose}>Cancel</button>
          <button type="submit" className="primary-button" disabled={saving}>{saving ? "Saving…" : "Save report"}</button>
        </div>
      </form>
    </div>
  );
}

export function IssueModal({ data, onClose, onSave }) {
  const [status, setStatus] = useState(
    data.status === "New report" ? "Reported" : data.status,
  );
  const [assigned, setAssigned] = useState("Unassigned");
  const [note, setNote] = useState("");
  const [validationError, setValidationError] = useState("");

  const saveWorkflow = () => {
    if (status === "Rejected" && !note.trim()) {
      setValidationError("A rejection reason is required.");
      return;
    }
    if (status === "Resolved" && !note.trim()) {
      setValidationError("A resolution note is required.");
      return;
    }
    setValidationError("");
    onSave?.({ status, assignedTeam: assigned, resolutionNote: note });
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className={`modal wide-modal issue-detail-modal ${data.category.toLowerCase()}`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className={`issue-modal-hero ${data.category.toLowerCase()}`}>
          <span className={`issue-modal-status ${data.severity.toLowerCase()}`}>
            <AlertTriangle size={13} /> {data.severity} · {status}
          </span>
          <button className="issue-modal-close" onClick={onClose}>
            <X size={18} />
          </button>
        </div>
        <div className="issue-modal-body">
          <div className="issue-modal-heading">
            <div>
              <h2>{data.title}</h2>
              <p className="issue-location"><MapPin size={15} /> {data.location} · 6.9482° N, 126.2311° E</p>
              <p className="modal-id">Report ID: #{data.id} · Filed {data.created_at ? new Date(data.created_at).toLocaleDateString() : "recently"} by {data.reporter || "walk-in resident"}</p>
              {data.due_at && <p className="modal-id">SLA due: {new Date(data.due_at).toLocaleString()}</p>}
            </div>
          </div>
          <div className="issue-modal-stats">
            <span><Users size={15} /> 214 followers</span>
            <span><Eye size={15} /> 1,045 views</span>
            <span><FileText size={15} /> 3 photos, 1 video</span>
          </div>
          <div className="modal-grid">
            <div>
              <div className="modal-section issue-description">
                <h3>Description</h3>
                <p>
                  {data.category === "Water"
                    ? "Entire purok has had no water supply for two days. Residents suspect a broken main line near the barangay hall."
                    : `This ${data.category.toLowerCase()} issue was reported by a resident and requires LGU operations review, field inspection, and a coordinated response.`}
                </p>
              </div>
              <div className="modal-section discussion-section">
                <h3>Official discussion <span className="semi-public-tag">◉ SEMI-PUBLIC</span></h3>
                <div className="discussion">
                  <div className="discussion-head"><b>{data.reporter || "Resident"}</b><small>Aug 2, 9:20 AM</small></div>
                  <p>
                    Please prioritize this issue and provide an update when the crew is scheduled.
                  </p>
                </div>
                <div className="discussion official">
                  <div className="discussion-head"><b>LGU Admin — Engr. Santos</b><small>1h ago</small></div>
                  <p>
                    We have received this report and are coordinating the next
                    field inspection.
                  </p>
                </div>
                <input className="reply-input" placeholder="Reply as LGU Admin…" />
              </div>
            </div>
            <div className="modal-section case-management">
              <h3>Case management</h3>
              <label>
                Status
                <select value={status} onChange={(event) => setStatus(event.target.value)}>
                  <option>Reported</option>
                  <option>Verified by inspector</option>
                  <option>Rejected</option>
                  <option>In progress</option>
                  <option>Resolved</option>
                </select>
              </label>
              <label>
                Assign to team
                <select value={assigned} onChange={(event) => setAssigned(event.target.value)}>
                  <option>Unassigned</option>
                  {(data.teams || []).map((team) => <option key={team.id} value={team.name}>{team.name}{team.department ? ` — ${team.department}` : ""}</option>)}
                </select>
              </label>
              <label>
                Priority
                <select>
                  <option>Critical</option>
                  <option>High</option>
                  <option>Medium</option>
                  <option>Low</option>
                </select>
              </label>
              {(status === "Resolved" || status === "Rejected") && (
                <>
                  <label>
                    {status === "Rejected" ? "Rejection reason" : "Resolution note"}
                    <textarea
                      value={note}
                      onChange={(event) => setNote(event.target.value)}
                      placeholder={status === "Rejected" ? "Explain why this report was rejected…" : "Describe what was done…"}
                    />
                  </label>
                  <div className="before-after">
                    <button>
                      <FileText size={16} /> Before photo
                    </button>
                    <button>
                      <FileText size={16} /> After photo
                    </button>
                  </div>
                </>
              )}
              {validationError && <p className="form-error" role="alert">{validationError}</p>}
              <button
                className="primary-button full-button"
                onClick={saveWorkflow}
              >
                <CheckCircle2 size={16} /> Save changes
              </button>
              <button
                type="button"
                className="secondary-button full-button danger-button"
                onClick={() => onSave?.({ status: "Archived", assignedTeam: assigned, resolutionNote: "Archived by administrator" })}
              >
                Archive issue
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function UserModal({ user, onClose, onSave }) {
  const [standing, setStanding] = useState(user.standing);
  const [selectedAction, setSelectedAction] = useState(null);
  const [reason, setReason] = useState("Spam or duplicate reports");
  const [duration, setDuration] = useState("24 hours");
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const chooseAction = (action) => {
    setSelectedAction(action);
    setNote("");
  };

  const apply = async (next) => {
    setSaving(true);
    setError("");
    try {
      await onSave?.({ action: selectedAction, reason, duration, note });
      setStanding(next);
      setSelectedAction(null);
      setNote("");
    } catch (saveError) {
      setError(saveError.message || "Could not save moderation action.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal wide-modal user-detail-modal" onClick={(event) => event.stopPropagation()}>
        <div className="user-modal-header">
          <div className="user-modal-title-wrap">
            <span className="user-avatar large">
              {user.name
                .split(" ")
                .map((part) => part[0])
                .join("")
                .slice(0, 2)}
            </span>
            <div className="user-modal-identity">
              <h2>{user.name}</h2>
              <p className="user-email">{user.email}</p>
            </div>
          </div>
          <button className="modal-close user-modal-close" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <div className="modal-stats user-meta-row">
          <span><MapPin size={15} /> {user.barangay}</span>
          <span><FileText size={15} /> {user.reports} reports filed</span>
          <span><CalendarDays size={15} /> Joined {user.joined}</span>
          <span className={`status ${standing === "Active" ? "resolved" : "pending"}`}>
            <ShieldCheck size={11} /> {standing}
          </span>
        </div>

        <div className="user-modal-content">
          <div className="user-left-panel">
            <h3 className="report-section-title">Recent reports by this resident</h3>

            <div className="report-list">
              <div className="mini-report">
                <span className="report-icon">
                  <FileText size={13} />
                </span>
                <div>
                  <b>Deep pothole along Rizal St.</b>
                  <small>#MT-2026-881 · Aug 2, 2026</small>
                </div>
              </div>

              <div className="mini-report">
                <span className="report-icon">
                  <FileText size={13} />
                </span>
                <div>
                  <b>Cracked pavement, Chapel St.</b>
                  <small>#MT-2026-842 · Jul 15, 2026</small>
                </div>
              </div>
            </div>

            <div className="moderation-box">
              <h3>Moderation history</h3>
              <p>No moderation actions on record.</p>
            </div>
          </div>

          <div className="user-right-panel">
            <h3 className="trust-title">Trust &amp; safety</h3>

            <div className="safety-card-wrap">
              <div className="safety-card">
                <div className="safety-card-header">ACCOUNT STANDING</div>
                <p className="safety-note">No abuse flags on this account.</p>

                <div className="safety-actions">
                  <button
                    className={selectedAction === "warn" ? "selected" : ""}
                    onClick={() => chooseAction("warn")}
                  >
                    <AlertTriangle size={15} /> Warn
                  </button>
                  <button
                    className={selectedAction === "suspend" ? "selected" : ""}
                    onClick={() => chooseAction("suspend")}
                  >
                    <Clock3 size={15} /> Suspend
                  </button>
                  <button
                    className={`ban-button ${selectedAction === "ban" ? "selected" : ""}`}
                    onClick={() => chooseAction("ban")}
                  >
                    <Ban size={15} /> Ban
                  </button>
                </div>

                {selectedAction && (
                  <div className="selected-action-block">
                      <label>
                        Reason
                        <select value={reason} onChange={(event) => setReason(event.target.value)}>
                          <option>Spam or duplicate reports</option>
                          <option>Abusive or threatening language</option>
                          <option>Fraudulent account activity</option>
                        </select>
                      </label>
                      <label>
                        Duration
                        <select value={duration} onChange={(event) => setDuration(event.target.value)}>
                          <option>24 hours</option>
                          <option>3 days</option>
                          <option>7 days</option>
                          <option>Permanent</option>
                        </select>
                      </label>
                      <label>
                        Note
                        <textarea value={note} onChange={(event) => setNote(event.target.value)} />
                      </label>
                      {error && <p className="login-error" role="alert">{error}</p>}
                      <button
                        className={`primary-button full-button ${selectedAction}-action`}
                        onClick={() => apply(selectedAction === "suspend" ? "Suspended" : selectedAction === "ban" ? "Banned" : "Warned")}
                        disabled={saving}
                      >
                        {saving ? "Saving…" : "Apply action"}
                      </button>
                  </div>
                )}
              </div>

              <p className="safety-footer">
                The resident is notified automatically when a warning, suspension, or ban is issued. Every action is logged with your admin account.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
