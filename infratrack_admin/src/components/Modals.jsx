import { useEffect, useLayoutEffect, useRef, useState } from "react";
import {
  AlertTriangle,
  Ban,
  BarChart3,
  Bell,
  Flag,
  CalendarDays,
  CheckCircle2,
  Clock3,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  FileText,
  Eye,
  LayoutDashboard,
  MapPin,
  Map,
  Megaphone,
  ScrollText,
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
  const [step, setStep] = useState(0);
  const [targetRect, setTargetRect] = useState(null);
  const [isChangingStep, setIsChangingStep] = useState(false);
  const transitionTimer = useRef(null);
  const guideSteps = [
    {
      eyebrow: "InfraTrack guide",
      title: "Welcome to InfraTrack",
      description: "Use this dashboard to review infrastructure reports, coordinate response teams, and monitor service improvements across Mati City.",
      icon: LayoutDashboard,
      target: null,
    },
    {
      eyebrow: "InfraTrack guide",
      title: "The rail is your pipeline",
      description: "Use the sidebar to move from the overview to the issue queue, map, analytics, and administration tools.",
      icon: LayoutDashboard,
      target: "nav-overview",
    },
    {
      eyebrow: "Issue queue",
      title: "Review incoming reports",
      description: "Open the issue queue to verify new reports, assign response teams, and update progress.",
      icon: ClipboardList,
      target: "nav-queue",
    },
    {
      eyebrow: "Infrastructure map",
      title: "See issues by location",
      description: "Open the map to understand where infrastructure problems are concentrated across Mati City.",
      icon: Map,
      target: "nav-map",
    },
    {
      eyebrow: "Analytics & reports",
      title: "Track what needs attention",
      description: "Review trends, response performance, and resident ratings to guide your next action.",
      icon: BarChart3,
      target: "nav-analytics",
    },
    {
      eyebrow: "Administration",
      title: "Manage user accounts",
      description: "Use User Management to review residents, account status, and access permissions.",
      icon: Users,
      target: "nav-users",
    },
    {
      eyebrow: "Administration",
      title: "Publish a public advisory",
      description: "Create announcements that keep residents informed about infrastructure work and service updates.",
      icon: Megaphone,
      target: "nav-announce",
    },
    {
      eyebrow: "Administration",
      title: "Review published advisories",
      description: "Open Published Advisories to review the announcements currently available to the public.",
      icon: FileText,
      target: "nav-published",
    },
    {
      eyebrow: "Administration",
      title: "Review activity logs",
      description: "Use Activity Logs to trace important account, report, advisory, and system actions.",
      icon: ScrollText,
      target: "nav-logs",
    },
    {
      eyebrow: "Quick action",
      title: "Log a walk-in report",
      description: "Capture an issue reported directly at the LGU desk using the action button in the top bar.",
      icon: Flag,
      target: "walkin-report",
    },
    {
      eyebrow: "Updates",
      title: "Stay on top of changes",
      description: "Use notifications to quickly see new infrastructure reports and open the issue queue.",
      icon: Bell,
      target: "notifications",
    },
  ];
  const currentStep = guideSteps[step];
  const StepIcon = currentStep.icon;
  const isLastStep = step === guideSteps.length - 1;

  useEffect(() => () => {
    if (transitionTimer.current) window.clearTimeout(transitionTimer.current);
  }, []);

  const changeStep = (nextStep) => {
    if (isChangingStep || nextStep < 0 || nextStep >= guideSteps.length) return;
    setIsChangingStep(true);
    transitionTimer.current = window.setTimeout(() => {
      setStep(nextStep);
      setIsChangingStep(false);
    }, 220);
  };

  useLayoutEffect(() => {
    const updateTarget = () => {
      if (!currentStep.target) {
        setTargetRect(null);
        return;
      }
      const target = document.querySelector(`[data-tour-target="${currentStep.target}"]`);
      if (!target) {
        setTargetRect(null);
        return;
      }
      const rect = target.getBoundingClientRect();
      setTargetRect({ top: rect.top, left: rect.left, width: rect.width, height: rect.height });
    };
    updateTarget();
    window.addEventListener("resize", updateTarget);
    window.addEventListener("scroll", updateTarget, true);
    return () => {
      window.removeEventListener("resize", updateTarget);
      window.removeEventListener("scroll", updateTarget, true);
    };
  }, [currentStep.target]);

  const tourWidth = Math.min(420, window.innerWidth - 32);
  const tourGap = 16;
  const canFitRight = targetRect && targetRect.left + targetRect.width + tourGap + tourWidth <= window.innerWidth - 16;
  const tourPosition = targetRect
    ? {
        top: Math.min(Math.max(targetRect.top, 16), window.innerHeight - 300),
        left: canFitRight
          ? targetRect.left + targetRect.width + tourGap
          : Math.max(16, targetRect.left - tourWidth - tourGap),
      }
    : { top: "50%", left: "50%", transform: "translate(-50%, -50%)" };

  return (
    <div className={`help-tour-backdrop ${targetRect ? "has-target" : "welcome"}`}>
      {targetRect && (
        <div
          className="help-tour-spotlight"
          style={{
            top: targetRect.top - 6,
            left: targetRect.left - 6,
            width: targetRect.width + 12,
            height: targetRect.height + 12,
          }}
        />
      )}
      <div
        className={`modal help-tour-modal ${targetRect ? "" : "centered"}`}
        style={tourPosition}
        role="dialog"
        aria-modal="true"
        aria-labelledby="help-tour-title"
      >
        <button
          type="button"
          className="modal-close help-tour-close"
          aria-label="Close guide"
          onClick={(event) => {
            event.stopPropagation();
            onClose();
          }}
        >
          <X size={18} />
        </button>
        <div className={`help-tour-content ${isChangingStep ? "is-changing" : ""}`} key={step}>
          <div className="help-tour-topline">
            <span className="help-tour-eyebrow">{currentStep.eyebrow}</span>
            <span className="help-tour-count">{step + 1} / {guideSteps.length}</span>
          </div>
          <div className="help-tour-icon"><StepIcon size={20} /></div>
          <h2 id="help-tour-title">{currentStep.title}</h2>
          <p>{currentStep.description}</p>
        </div>
        <div className="help-tour-footer">
          <div className="help-tour-dots" aria-label={`Step ${step + 1} of ${guideSteps.length}`}>
            {guideSteps.map((item, index) => (
              <span className={index === step ? "active" : ""} key={item.title} />
            ))}
          </div>
          <div className="help-tour-actions">
            {step > 0 && (
              <button type="button" className="secondary-button" onClick={() => changeStep(step - 1)} disabled={isChangingStep}>
                <ChevronLeft size={15} /> Back
              </button>
            )}
            <button type="button" className="primary-button" onClick={() => (isLastStep ? onClose() : changeStep(step + 1))} disabled={isChangingStep}>
              {isLastStep ? "Done" : "Next"} {!isLastStep && <ChevronRight size={15} />}
            </button>
          </div>
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
  const [isSaving, setIsSaving] = useState(false);
  const [isArchiving, setIsArchiving] = useState(false);

  const saveChanges = async (changes, archiving = false) => {
    setIsSaving(true);
    setIsArchiving(archiving);
    setValidationError("");
    try {
      await onSave?.(changes);
    } catch (saveError) {
      setValidationError(saveError instanceof Error ? saveError.message : "Could not save report changes.");
    } finally {
      setIsSaving(false);
      setIsArchiving(false);
    }
  };

  const saveWorkflow = () => {
    if (status === "Rejected" && !note.trim()) {
      setValidationError("A rejection reason is required.");
      return;
    }
    if (status === "Resolved" && !note.trim()) {
      setValidationError("A resolution note is required.");
      return;
    }
    void saveChanges({ status, assignedTeam: assigned, resolutionNote: note });
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
                disabled={isSaving}
              >
                <CheckCircle2 size={16} /> {isSaving ? "Saving…" : "Save changes"}
              </button>
              <button
                type="button"
                className="secondary-button full-button danger-button"
                onClick={() => void saveChanges({ status: "Archived", assignedTeam: assigned, resolutionNote: "Archived by administrator" }, true)}
                disabled={isSaving}
              >
                {isArchiving ? "Archiving…" : "Archive issue"}
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
