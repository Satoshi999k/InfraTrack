import { useEffect, useLayoutEffect, useRef, useState } from "react";
import {
  AlertTriangle,
  Ban,
  BarChart3,
  Bell,
  Building2,
  Flag,
  CalendarDays,
  CheckCircle2,
  Clock3,
  ChevronLeft,
  ChevronRight,
  ChevronDown,
  ChevronUp,
  ClipboardList,
  FileText,
  Eye,
  Heart,
  Image as ImageIcon,
  LayoutDashboard,
  MapPin,
  Map,
  Megaphone,
  MessageCircle,
  ScanEye,
  ScrollText,
  Send,
  ShieldAlert,
  ShieldCheck,
  Sparkles,
  Star,
  Users,
  X,
} from "lucide-react";
import { apiFetch } from "../api";
import { progressUpdateError } from "../../progressWorkflow.js";
import {
  isReportDiscussionOpen,
  REPORT_COMMENT_MAX_LENGTH,
} from "../../reportDiscussion.js";
import { REPORT_CATEGORIES } from "../../reportCategories.js";
import { startVisiblePolling } from "../visiblePolling.js";
import { formatAdvisoryMention } from "../../advisoryReply.js";

export function Modal({
  data,
  onClose,
  onSave,
  onUserSave,
  onUserVerification,
  onFetchUserReports,
}) {
  if (data.type === "user")
    return (
      <UserModal
        user={data.user}
        onClose={onClose}
        onSave={onUserSave}
        onVerification={onUserVerification}
        onFetchReports={onFetchUserReports}
      />
    );
  if (data.type === "walkin")
    return <WalkInModal onClose={onClose} onSave={onSave} />;
  if (data.type === "help") return <HelpModal onClose={onClose} />;
  if (data.type === "advisory-engagement")
    return <AdvisoryEngagementModal data={data} onClose={onClose} />;
  return <IssueModal data={data} onClose={onClose} onSave={onSave} />;
}

function AdvisoryEngagementModal({ data, onClose }) {
  const [engagement, setEngagement] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [replyDraft, setReplyDraft] = useState("");
  const [replyingTo, setReplyingTo] = useState(null);
  const [replyError, setReplyError] = useState("");
  const [sendingReply, setSendingReply] = useState(false);
  const replyInputRef = useRef(null);

  useEffect(() => {
    const closeOnEscape = (event) => {
      if (event.key === "Escape") onClose();
    };
    document.addEventListener("keydown", closeOnEscape);
    return () => document.removeEventListener("keydown", closeOnEscape);
  }, [onClose]);

  useEffect(() => {
    let active = true;
    const loadEngagement = async () => {
      try {
        const response = await apiFetch(
          `/advisories/${encodeURIComponent(data.advisoryId)}/engagement`,
        );
        const result = await response.json();
        if (!response.ok) {
          throw new Error(result.error || "Could not load advisory activity.");
        }
        if (active) setEngagement(result);
      } catch (loadError) {
        if (active) {
          setError(
            loadError instanceof Error
              ? loadError.message
              : "Could not load advisory activity.",
          );
        }
      } finally {
        if (active) setLoading(false);
      }
    };

    loadEngagement();
    return () => {
      active = false;
    };
  }, [data.advisoryId]);

  const advisory = engagement?.advisory;
  const comments = engagement?.comments ?? [];
  const reactions = engagement?.reactions ?? [];

  return (
    <div className="modal-backdrop advisory-engagement-backdrop" onClick={onClose}>
      <section
        className="modal advisory-engagement-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="advisory-engagement-title"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="advisory-engagement-header">
          <div>
            <span>Public advisory</span>
            <h2 id="advisory-engagement-title">
              {advisory?.title || data.advisoryTitle || "Advisory activity"}
            </h2>
          </div>
          <button
            type="button"
            className="modal-close"
            onClick={onClose}
            aria-label="Close advisory activity"
          >
            <X size={18} />
          </button>
        </header>
        {loading ? (
          <div className="advisory-engagement-state" role="status">
            Loading advisory activity…
          </div>
        ) : error ? (
          <div className="advisory-engagement-state error" role="alert">
            {error}
          </div>
        ) : (
          <div className="advisory-engagement-body">
            <article className="advisory-post-preview">
              <div className="advisory-post-author">
                <span aria-hidden="true">
                  <Building2 size={18} />
                </span>
                <div>
                  <strong>{advisory?.author_name || "Mati City"}</strong>
                  <small>
                    Official city advisory
                    {advisory?.published_at || advisory?.created_at
                      ? ` · ${new Date(
                          advisory.published_at || advisory.created_at,
                        ).toLocaleString()}`
                      : ""}
                  </small>
                </div>
              </div>
              <p className="advisory-engagement-message">
                {advisory?.message}
              </p>
            </article>
            <div className="advisory-engagement-stats">
              <div>
                <Heart size={16} aria-hidden="true" />
                <strong>{advisory?.reaction_count ?? reactions.length}</strong>
                <span>Likes</span>
              </div>
              <div>
                <MessageCircle size={16} aria-hidden="true" />
                <strong>{advisory?.comment_count ?? comments.length}</strong>
                <span>Comments</span>
              </div>
            </div>
            <section className="advisory-engagement-section">
              <div className="advisory-engagement-section-heading">
                <h3>Resident comments</h3>
                <span>{advisory?.comment_count ?? comments.length}</span>
              </div>
              {Number(advisory?.comment_count || 0) > comments.length && (
                <p className="advisory-engagement-limit">
                  Showing the {comments.length} most recent comments.
                </p>
              )}
              {comments.length ? (
                <div className="advisory-engagement-comments">
                  {comments.map((comment) => (
                    <article
                      className={`advisory-engagement-comment ${comment.author_role && comment.author_role !== "resident" ? "from-staff" : ""}`}
                      key={comment.id}
                    >
                      <span className="advisory-comment-avatar" aria-hidden="true">
                        {comment.author_name?.trim().charAt(0).toUpperCase() ||
                          "R"}
                      </span>
                      <div className="advisory-comment-content">
                        <div className="advisory-comment-bubble">
                          <div className="advisory-comment-meta">
                            <strong>{comment.author_name}</strong>
                            {comment.author_role &&
                              comment.author_role !== "resident" && (
                                <span className="advisory-comment-staff">
                                  City staff
                                </span>
                              )}
                          </div>
                          <p>{comment.body}</p>
                        </div>
                        <div className="advisory-comment-actions">
                          <time dateTime={comment.created_at}>
                            {comment.created_at
                              ? new Date(comment.created_at).toLocaleString()
                              : ""}
                          </time>
                          <button
                            type="button"
                            onClick={() => {
                              setReplyingTo(comment);
                              setReplyDraft(
                                formatAdvisoryMention(comment.author_name),
                              );
                              setReplyError("");
                              window.requestAnimationFrame(() => {
                                replyInputRef.current?.focus();
                                replyInputRef.current?.scrollIntoView({
                                  block: "nearest",
                                  behavior: "smooth",
                                });
                              });
                            }}
                          >
                            Reply
                          </button>
                        </div>
                      </div>
                    </article>
                  ))}
                </div>
              ) : (
                <p className="advisory-engagement-empty">
                  No comments yet.
                </p>
              )}
            </section>
            <section className="advisory-engagement-section">
              <div className="advisory-engagement-section-heading">
                <h3>Liked by</h3>
                <span>{advisory?.reaction_count ?? reactions.length}</span>
              </div>
              {reactions.length ? (
                <ul className="advisory-engagement-likes">
                  {reactions.map((reaction) => (
                    <li key={reaction.user_id}>
                      <span aria-hidden="true">
                        {reaction.user_name?.trim().charAt(0).toUpperCase() ||
                          "R"}
                      </span>
                      <strong>{reaction.user_name}</strong>
                    </li>
                  ))}
                  {Number(advisory?.reaction_count || 0) > reactions.length && (
                    <li className="advisory-engagement-more-likes">
                      and {Number(advisory.reaction_count) - reactions.length}{" "}
                      more
                    </li>
                  )}
                </ul>
              ) : (
                <p className="advisory-engagement-empty">
                  No likes yet.
                </p>
              )}
            </section>
          </div>
        )}
        {!loading && !error && (
          <form
            className="advisory-reply-composer"
            onSubmit={async (event) => {
              event.preventDefault();
              const body = replyDraft.trim();
              if (!body || sendingReply) return;
              setSendingReply(true);
              setReplyError("");
              try {
                const response = await apiFetch(
                  `/advisories/${encodeURIComponent(data.advisoryId)}/comments`,
                  {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                      body,
                      ...(replyingTo
                        ? { reply_to_comment_id: replyingTo.id }
                        : {}),
                    }),
                  },
                );
                const result = await response.json();
                if (!response.ok) {
                  throw new Error(result.error || "Could not post your reply.");
                }
                setEngagement((current) => ({
                  ...current,
                  advisory: {
                    ...current.advisory,
                    comment_count:
                      Number(current.advisory.comment_count || 0) + 1,
                  },
                  comments: [...current.comments, result.comment],
                }));
                setReplyDraft("");
                setReplyingTo(null);
                if (result.warning) setReplyError(result.warning);
              } catch (sendError) {
                setReplyError(
                  sendError instanceof Error
                    ? sendError.message
                    : "Could not post your reply.",
                );
              } finally {
                setSendingReply(false);
              }
            }}
          >
            {replyingTo && (
              <div className="advisory-reply-context" role="status">
                <span>
                  Replying to <strong>{replyingTo.author_name}</strong>
                </span>
                <button
                  type="button"
                  onClick={() => {
                    setReplyingTo(null);
                    setReplyDraft("");
                    setReplyError("");
                  }}
                  aria-label="Cancel reply"
                >
                  <X size={15} aria-hidden="true" />
                </button>
              </div>
            )}
            <div className="advisory-reply-input-row">
              <span className="advisory-reply-avatar" aria-hidden="true">
                <Building2 size={16} />
              </span>
              <textarea
                ref={replyInputRef}
                aria-label={
                  replyingTo
                    ? `Reply to ${replyingTo.author_name}`
                    : "Write an advisory comment"
                }
                placeholder="Write a comment…"
                maxLength={1000}
                rows={2}
                value={replyDraft}
                onChange={(event) => {
                  setReplyDraft(event.target.value);
                  if (replyError) setReplyError("");
                }}
              />
              <button
                type="submit"
                className="advisory-reply-send"
                disabled={!replyDraft.trim() || sendingReply}
              >
                {sendingReply ? (
                  <span className="button-spinner" aria-label="Sending" />
                ) : (
                  <Send size={16} aria-hidden="true" />
                )}
                <span>
                  {sendingReply
                    ? "Sending"
                    : replyingTo
                      ? "Reply"
                      : "Post"}
                </span>
              </button>
            </div>
            <div className="advisory-reply-footer">
              <span role={replyError ? "alert" : undefined}>
                {replyError || "Replies are visible to residents on this advisory."}
              </span>
              <span>{replyDraft.length}/1000</span>
            </div>
          </form>
        )}
      </section>
    </div>
  );
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
      description:
        "Use this dashboard to review infrastructure reports, coordinate response teams, and monitor service improvements across Mati City.",
      icon: LayoutDashboard,
      target: null,
    },
    {
      eyebrow: "InfraTrack guide",
      title: "The rail is your pipeline",
      description:
        "Use the sidebar to move from the overview to the issue queue, map, analytics, and administration tools.",
      icon: LayoutDashboard,
      target: "nav-overview",
    },
    {
      eyebrow: "Issue queue",
      title: "Review incoming reports",
      description:
        "Open the issue queue to verify new reports, assign response teams, and update progress.",
      icon: ClipboardList,
      target: "nav-queue",
    },
    {
      eyebrow: "Infrastructure map",
      title: "See issues by location",
      description:
        "Open the map to understand where infrastructure problems are concentrated across Mati City.",
      icon: Map,
      target: "nav-map",
    },
    {
      eyebrow: "Analytics & reports",
      title: "Track what needs attention",
      description:
        "Review trends, response performance, and resident ratings to guide your next action.",
      icon: BarChart3,
      target: "nav-analytics",
    },
    {
      eyebrow: "Administration",
      title: "Manage user accounts",
      description:
        "Use User Management to review residents, account status, and access permissions.",
      icon: Users,
      target: "nav-users",
    },
    {
      eyebrow: "Administration",
      title: "Publish a public advisory",
      description:
        "Create announcements that keep residents informed about infrastructure work and service updates.",
      icon: Megaphone,
      target: "nav-announce",
    },
    {
      eyebrow: "Administration",
      title: "Review published advisories",
      description:
        "Open Published Advisories to review the announcements currently available to the public.",
      icon: FileText,
      target: "nav-published",
    },
    {
      eyebrow: "Administration",
      title: "Review activity logs",
      description:
        "Use Activity Logs to trace important account, report, advisory, and system actions.",
      icon: ScrollText,
      target: "nav-logs",
    },
    {
      eyebrow: "Quick action",
      title: "Log a walk-in report",
      description:
        "Capture an issue reported directly at the LGU desk using the action button in the top bar.",
      icon: Flag,
      target: "walkin-report",
    },
    {
      eyebrow: "Updates",
      title: "Stay on top of changes",
      description:
        "Use notifications to quickly see new infrastructure reports and open the issue queue.",
      icon: Bell,
      target: "notifications",
    },
  ];
  const currentStep = guideSteps[step];
  const StepIcon = currentStep.icon;
  const isLastStep = step === guideSteps.length - 1;

  useEffect(
    () => () => {
      if (transitionTimer.current) window.clearTimeout(transitionTimer.current);
    },
    [],
  );

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
      const target = document.querySelector(
        `[data-tour-target="${currentStep.target}"]`,
      );
      if (!target) {
        setTargetRect(null);
        return;
      }
      const rect = target.getBoundingClientRect();
      setTargetRect({
        top: rect.top,
        left: rect.left,
        width: rect.width,
        height: rect.height,
      });
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
  const canFitRight =
    targetRect &&
    targetRect.left + targetRect.width + tourGap + tourWidth <=
      window.innerWidth - 16;
  const tourPosition = targetRect
    ? {
        top: Math.min(Math.max(targetRect.top, 16), window.innerHeight - 300),
        left: canFitRight
          ? targetRect.left + targetRect.width + tourGap
          : Math.max(16, targetRect.left - tourWidth - tourGap),
      }
    : { top: "50%", left: "50%", transform: "translate(-50%, -50%)" };

  return (
    <div
      className={`help-tour-backdrop ${targetRect ? "has-target" : "welcome"}`}
    >
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
        <div
          className={`help-tour-content ${isChangingStep ? "is-changing" : ""}`}
          key={step}
        >
          <div className="help-tour-topline">
            <span className="help-tour-eyebrow">{currentStep.eyebrow}</span>
            <span className="help-tour-count">
              {step + 1} / {guideSteps.length}
            </span>
          </div>
          <div
            className={`help-tour-icon ${step === 0 ? "help-tour-logo" : ""}`}
          >
            {step === 0 ? <Building2 size={21} /> : <StepIcon size={20} />}
          </div>
          <h2 id="help-tour-title">{currentStep.title}</h2>
          <p>{currentStep.description}</p>
        </div>
        <div className="help-tour-footer">
          <div
            className="help-tour-dots"
            aria-label={`Step ${step + 1} of ${guideSteps.length}`}
          >
            {guideSteps.map((item, index) => (
              <span
                className={index === step ? "active" : ""}
                key={item.title}
              />
            ))}
          </div>
          <div className="help-tour-actions">
            {step > 0 && (
              <button
                type="button"
                className="secondary-button"
                onClick={() => changeStep(step - 1)}
                disabled={isChangingStep}
              >
                <ChevronLeft size={15} /> Back
              </button>
            )}
            <button
              type="button"
              className="primary-button"
              onClick={() => (isLastStep ? onClose() : changeStep(step + 1))}
              disabled={isChangingStep}
            >
              {isLastStep ? "Done" : "Next"}{" "}
              {!isLastStep && <ChevronRight size={15} />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function WalkInModal({ onClose, onSave }) {
  const modalRef = useRef(null);
  const onCloseRef = useRef(onClose);
  const savingRef = useRef(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("Roads");
  const [location, setLocation] = useState("Mati City");
  const [severity, setSeverity] = useState("Medium");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");
  onCloseRef.current = onClose;
  savingRef.current = saving;

  useEffect(() => {
    const previousFocus = document.activeElement;
    const modal = modalRef.current;
    const firstInput = modal?.querySelector("input");
    firstInput?.focus();

    const handleKeyDown = (event) => {
      if (event.key === "Escape" && !savingRef.current) {
        event.preventDefault();
        onCloseRef.current();
        return;
      }

      if (event.key !== "Tab" || !modal) return;
      const focusable = modal.querySelectorAll(
        "button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled)",
      );
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      if (previousFocus instanceof HTMLElement) previousFocus.focus();
    };
  }, []);

  const submit = async (event) => {
    event.preventDefault();
    if (saving) return;
    if (!title.trim() || !description.trim() || !location.trim()) {
      setSaveError(
        "Complete the title, location, and description before saving.",
      );
      return;
    }
    setSaveError("");
    setSaving(true);
    try {
      await onSave({
        title: title.trim(),
        description: description.trim(),
        category,
        location: location.trim(),
        severity,
      });
    } catch (error) {
      setSaveError(
        error.message || "Could not save the report. Please try again.",
      );
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      className="modal-backdrop walkin-modal-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !saving) onClose();
      }}
    >
      <form
        ref={modalRef}
        className="modal advisory-editor-modal walkin-report-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="walkin-report-title"
        aria-describedby="walkin-report-description"
        aria-busy={saving}
        onClick={(event) => event.stopPropagation()}
        onSubmit={submit}
      >
        <button
          type="button"
          className="modal-close"
          aria-label="Close walk-in report"
          onClick={onClose}
          disabled={saving}
        >
          <X size={18} />
        </button>
        <div className="advisory-edit-header">
          <span className="walkin-modal-eyebrow">Field report</span>
          <h2 id="walkin-report-title">Log a walk-in report</h2>
          <p id="walkin-report-description">
            Record an infrastructure issue reported at the office.
          </p>
        </div>
        <label htmlFor="walkin-title">Issue title</label>
        <input
          id="walkin-title"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder="e.g. Broken streetlight near city hall"
          required
          disabled={saving}
        />
        <div className="walkin-field-grid">
          <div>
            <label htmlFor="walkin-category">Category</label>
            <select
              id="walkin-category"
              value={category}
              onChange={(event) => setCategory(event.target.value)}
              disabled={saving}
            >
              {REPORT_CATEGORIES.map((reportCategory) => (
                <option key={reportCategory}>{reportCategory}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="walkin-severity">Severity</label>
            <select
              id="walkin-severity"
              value={severity}
              onChange={(event) => setSeverity(event.target.value)}
              disabled={saving}
            >
              <option>Low</option>
              <option>Medium</option>
              <option>High</option>
              <option>Critical</option>
            </select>
          </div>
        </div>
        <label htmlFor="walkin-location">Location or barangay</label>
        <input
          id="walkin-location"
          value={location}
          onChange={(event) => setLocation(event.target.value)}
          placeholder="e.g. Brgy. Central"
          required
          disabled={saving}
        />
        <label htmlFor="walkin-description">Description</label>
        <textarea
          id="walkin-description"
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          placeholder="Describe the issue and safety concern..."
          required
          disabled={saving}
        />
        {saveError && (
          <p className="walkin-report-error" role="alert">
            {saveError}
          </p>
        )}
        <div className="advisory-edit-actions">
          <button
            type="button"
            className="secondary-button"
            onClick={onClose}
            disabled={saving}
          >
            Cancel
          </button>
          <button type="submit" className="primary-button" disabled={saving}>
            {saving ? "Saving..." : "Save report"}
          </button>
        </div>
      </form>
    </div>
  );
}

export function IssueModal({ data, onClose, onSave }) {
  const latitude = Number(data.latitude);
  const longitude = Number(data.longitude);
  const coordinates =
    Number.isFinite(latitude) && Number.isFinite(longitude)
      ? `${latitude.toFixed(5)}° N, ${longitude.toFixed(5)}° E`
      : "Coordinates unavailable";
  const mediaCount = Number(data.media_count) || 0;
  const photoCount = Number(data.photo_count) || 0;
  const videoCount = Number(data.video_count) || 0;
  const mediaSummary =
    mediaCount === 0
      ? "No media attached"
      : `${photoCount} photo${photoCount === 1 ? "" : "s"}${videoCount ? `, ${videoCount} video${videoCount === 1 ? "" : "s"}` : ""}`;
  const [status, setStatus] = useState(
    data.status === "New report" ? "Reported" : data.status,
  );
  const [severity, setSeverity] = useState(
    ["Low", "Medium", "High", "Critical"].includes(data.severity)
      ? data.severity
      : "Medium",
  );
  const isSlaOverdue = Boolean(
    data.due_at &&
    new Date(data.due_at).getTime() < Date.now() &&
    !["Resolved", "Rejected", "Archived"].includes(status),
  );
  const [assigned, setAssigned] = useState(
    data.assigned_team || data.assignedTeam || "Unassigned",
  );
  const [progressPercentage, setProgressPercentage] = useState(
    Number(data.progress_percentage) || 0,
  );
  const [progressNote, setProgressNote] = useState("");
  const [discussion, setDiscussion] = useState([]);
  const [discussionExpanded, setDiscussionExpanded] = useState(false);
  const [discussionLoading, setDiscussionLoading] = useState(true);
  const [discussionError, setDiscussionError] = useState("");
  const [ratings, setRatings] = useState([]);
  const [ratingsLoading, setRatingsLoading] = useState(true);
  const [ratingsError, setRatingsError] = useState("");
  const [reply, setReply] = useState("");
  const [isPostingReply, setIsPostingReply] = useState(false);
  const [note, setNote] = useState("");
  const [validationError, setValidationError] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [isArchiving, setIsArchiving] = useState(false);
  const [beforePhoto, setBeforePhoto] = useState(data.media_url || "");
  const [afterPhoto, setAfterPhoto] = useState(data.resolution_media_url || "");
  const [isUploadingBeforePhoto, setIsUploadingBeforePhoto] = useState(false);
  const [isUploadingAfterPhoto, setIsUploadingAfterPhoto] = useState(false);
  const [mediaError, setMediaError] = useState(false);
  const beforePhotoInput = useRef(null);
  const afterPhotoInput = useRef(null);

  useEffect(() => {
    if (!data.id) return undefined;
    let active = true;
    setDiscussion([]);
    setDiscussionExpanded(false);
    setDiscussionError("");
    setDiscussionLoading(true);
    const refreshDiscussion = async () => {
      try {
        const response = await apiFetch(
          `/issues/${encodeURIComponent(data.id)}/discussion`,
        );
        const result = await response.json();
        if (!response.ok) {
          throw new Error(result.error || "Could not load the discussion.");
        }
        if (active) {
          setDiscussion(result.comments ?? []);
          setDiscussionError("");
        }
      } catch (error) {
        if (active) {
          setDiscussionError(
            error instanceof Error
              ? error.message
              : "Could not load the discussion.",
          );
        }
      } finally {
        if (active) setDiscussionLoading(false);
      }
    };
    const stopPolling = startVisiblePolling(refreshDiscussion, {
      documentRef: document,
      intervalMs: 15000,
    });

    return () => {
      active = false;
      stopPolling();
    };
  }, [data.id]);

  useEffect(() => {
    if (!data.id) return undefined;
    let active = true;
    setRatings([]);
    setRatingsError("");
    setRatingsLoading(true);
    const loadRatings = async () => {
      try {
        const response = await apiFetch(
          `/issues/${encodeURIComponent(data.id)}/ratings`,
        );
        const result = await response.json();
        if (!response.ok) {
          throw new Error(result.error || "Could not load resident feedback.");
        }
        if (active) {
          setRatings(result.ratings ?? []);
          setRatingsError("");
        }
      } catch (error) {
        if (active) {
          setRatingsError(
            error instanceof Error
              ? error.message
              : "Could not load resident feedback.",
          );
        }
      } finally {
        if (active) setRatingsLoading(false);
      }
    };
    void loadRatings();
    return () => {
      active = false;
    };
  }, [data.id]);

  const postDiscussionReply = async (event) => {
    event.preventDefault();
    const body = reply.trim();
    if (!body || isPostingReply) return;
    setIsPostingReply(true);
    setDiscussionError("");
    try {
      const response = await apiFetch(
        `/issues/${encodeURIComponent(data.id)}/discussion`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ body }),
        },
      );
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || "Could not send your reply.");
      }
      setDiscussion((current) => [...current, result.comment]);
      setReply("");
    } catch (error) {
      setDiscussionError(
        error instanceof Error ? error.message : "Could not send your reply.",
      );
    } finally {
      setIsPostingReply(false);
    }
  };

  const saveChanges = async (changes, archiving = false) => {
    setIsSaving(true);
    setIsArchiving(archiving);
    setValidationError("");
    try {
      await onSave?.(changes);
    } catch (saveError) {
      setValidationError(
        saveError instanceof Error
          ? saveError.message
          : "Could not save report changes.",
      );
    } finally {
      setIsSaving(false);
      setIsArchiving(false);
    }
  };

  const saveWorkflow = () => {
    const currentStatus =
      data.status === "New report" ? "Reported" : data.status;
    const progressError = progressUpdateError({
      currentStatus,
      nextStatus: status,
      currentProgress: Number(data.progress_percentage) || 0,
      nextProgress: progressPercentage,
      progressNote,
    });
    if (progressError) {
      setValidationError(progressError);
      return;
    }
    if (status === "Rejected" && !note.trim()) {
      setValidationError("A rejection reason is required.");
      return;
    }
    if (status === "Resolved" && !note.trim()) {
      setValidationError("A resolution note is required.");
      return;
    }
    void saveChanges({
      status,
      assignedTeam: assigned,
      severity,
      resolutionNote: note,
      progressPercentage,
      progressNote,
      beforeMediaUrl: beforePhoto || null,
      afterMediaUrl: afterPhoto || null,
    });
  };

  const replaceBeforePhoto = async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setIsUploadingBeforePhoto(true);
    setValidationError("");
    try {
      const formData = new FormData();
      formData.append("file", file);
      const response = await apiFetch("/uploads", {
        method: "POST",
        body: formData,
      });
      const result = await response.json();
      if (!response.ok || !result.url)
        throw new Error(result.error || "Could not upload replacement photo.");
      setBeforePhoto(result.url);
    } catch (error) {
      setValidationError(
        error instanceof Error
          ? error.message
          : "Could not upload replacement photo.",
      );
    } finally {
      setIsUploadingBeforePhoto(false);
    }
  };

  const uploadAfterPhoto = async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setIsUploadingAfterPhoto(true);
    setValidationError("");
    try {
      const formData = new FormData();
      formData.append("file", file);
      const response = await apiFetch("/uploads", {
        method: "POST",
        body: formData,
      });
      const result = await response.json();
      if (!response.ok || !result.url)
        throw new Error(result.error || "Could not upload the after photo.");
      setAfterPhoto(result.url);
    } catch (error) {
      setValidationError(
        error instanceof Error
          ? error.message
          : "Could not upload the after photo.",
      );
    } finally {
      setIsUploadingAfterPhoto(false);
    }
  };

  return (
    <div className="modal-backdrop issue-modal-backdrop" onClick={onClose}>
      <div
        className={`modal wide-modal issue-detail-modal ${data.category.toLowerCase()}`}
        onClick={(event) => event.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="issue-modal-title"
      >
        <div
          className={`issue-modal-hero ${data.category.toLowerCase()}${data.media_url && !mediaError ? " has-media" : ""}`}
        >
          {data.media_url && !mediaError && (
            <img
              className="issue-modal-media"
              src={data.media_url}
              alt={`Report attachment for ${data.title}`}
              onError={() => setMediaError(true)}
            />
          )}
          {(!data.media_url || mediaError) && (
            <div
              className="issue-modal-empty-media"
              aria-label="No report photo available"
            >
              <ImageIcon size={24} />
              <span>No report photo provided</span>
            </div>
          )}
          <div className="issue-modal-hero-badges">
            <span className={`issue-modal-status ${severity.toLowerCase()}`}>
              <AlertTriangle size={13} /> Priority {severity}
            </span>
            <span className="issue-modal-current-status">{status}</span>
          </div>
          <button
            type="button"
            className="issue-modal-close"
            onClick={onClose}
            aria-label="Close issue details"
          >
            <X size={18} />
          </button>
        </div>
        <div className="issue-modal-body">
          <div className="issue-modal-heading">
            <div>
              <h2 id="issue-modal-title">{data.title}</h2>
              <p className="issue-location">
                <MapPin size={15} /> {data.location} · {coordinates}
              </p>
            </div>
          </div>
          <div className="issue-modal-metadata" aria-label="Report information">
            <div className="issue-modal-metadata-item">
              <span className="issue-modal-metadata-label">Report ID</span>
              <strong>#{data.id}</strong>
            </div>
            <div className="issue-modal-metadata-item">
              <span className="issue-modal-metadata-label">Submitted</span>
              <strong>
                {data.created_at
                  ? new Date(data.created_at).toLocaleDateString()
                  : "Recently"}
              </strong>
              <span className="issue-modal-metadata-detail">
                by {data.reporter || "walk-in resident"}
              </span>
            </div>
            {data.due_at && (
              <div
                className={`issue-modal-metadata-item sla${isSlaOverdue ? " overdue" : ""}`}
              >
                <span className="issue-modal-metadata-label">
                  <Clock3 size={13} />{" "}
                  {isSlaOverdue ? "SLA overdue" : "SLA due"}
                </span>
                <strong>{new Date(data.due_at).toLocaleString()}</strong>
              </div>
            )}
          </div>
          <div className="issue-modal-stats">
            <span>
              <FileText size={15} /> {mediaSummary}
            </span>
            <span>
              <Eye size={15} /> Last updated{" "}
              {data.updated_at
                ? new Date(data.updated_at).toLocaleString()
                : "Unavailable"}
            </span>
          </div>
          <div className="modal-grid">
            <div>
              <div className="modal-section issue-description">
                <h3>Description</h3>
                <p>{data.description || "No description provided."}</p>
              </div>
              <section
                className="resident-review-section"
                aria-labelledby="resident-review-title"
              >
                <div className="resident-review-heading">
                  <div>
                    <span>COMMUNITY FEEDBACK</span>
                    <h3 id="resident-review-title">Resident review</h3>
                  </div>
                  {!ratingsLoading && ratings.length > 0 && (
                    <span className="resident-review-count">
                      {ratings.length}{" "}
                      {ratings.length === 1 ? "review" : "reviews"}
                    </span>
                  )}
                </div>
                {ratingsLoading ? (
                  <p className="resident-review-state" role="status">
                    Loading resident feedback...
                  </p>
                ) : ratingsError ? (
                  <p className="resident-review-error" role="alert">
                    {ratingsError}
                  </p>
                ) : ratings.length === 0 ? (
                  <p className="resident-review-state">
                    {status === "Resolved"
                      ? "No resident review has been submitted yet."
                      : "Resident feedback will appear here after the report is resolved."}
                  </p>
                ) : (
                  <div className="resident-review-list">
                    {ratings.map((review, index) => {
                      const rating = Math.min(
                        5,
                        Math.max(0, Number(review.rating) || 0),
                      );
                      return (
                        <article
                          className="resident-review-card"
                          key={`${review.created_at || "review"}-${index}`}
                        >
                          <div className="resident-review-meta">
                            <strong>
                              {review.reviewer_name || "Resident"}
                            </strong>
                            <time>
                              {review.created_at
                                ? new Date(review.created_at).toLocaleString()
                                : "Recently"}
                            </time>
                          </div>
                          <div
                            className="resident-review-rating"
                            aria-label={`${rating} out of 5 stars`}
                          >
                            <span className="resident-review-stars">
                              {Array.from({ length: 5 }, (_, star) => (
                                <Star
                                  key={star}
                                  size={15}
                                  className={star < rating ? "is-filled" : ""}
                                  aria-hidden="true"
                                />
                              ))}
                            </span>
                            <strong>{rating}/5</strong>
                          </div>
                          {review.comment?.trim() ? (
                            <p>{review.comment}</p>
                          ) : (
                            <p className="resident-review-no-comment">
                              No written comment was provided.
                            </p>
                          )}
                        </article>
                      );
                    })}
                  </div>
                )}
              </section>
              <div className="modal-section discussion-section">
                <div className="discussion-section-heading">
                  <div>
                    <h3>Official discussion</h3>
                    <p>
                      Publicly viewable; only the reporter and response team can
                      reply.
                    </p>
                  </div>
                  <span className="semi-public-tag">
                    Semi-public · {discussion.length} repl
                    {discussion.length === 1 ? "y" : "ies"}
                  </span>
                </div>
                <div className="discussion resident">
                  <div className="discussion-head">
                    <b>{data.reporter || "Resident"}</b>
                    <small>
                      {data.created_at
                        ? new Date(data.created_at).toLocaleString()
                        : "Recently"}
                    </small>
                  </div>
                  <p>{data.description || "No report note was provided."}</p>
                </div>
                {data.latest_event_note && (
                  <div className="discussion official">
                    <div className="discussion-head">
                      <b>Latest status update</b>
                      <small>
                        {data.latest_event_at
                          ? new Date(data.latest_event_at).toLocaleString()
                          : "Recently"}
                      </small>
                    </div>
                    <p>{data.latest_event_note}</p>
                  </div>
                )}
                <div
                  className={`discussion-stream ${discussionExpanded ? "expanded" : ""}`}
                  id="issue-discussion-replies"
                  aria-live="polite"
                  aria-busy={discussionLoading}
                >
                  {(discussionExpanded || discussion.length <= 2
                    ? discussion
                    : discussion.slice(-2)
                  ).map((comment) => (
                    <article
                      className={`discussion ${comment.author_role === "resident" ? "resident" : "official"}`}
                      key={comment.id}
                    >
                      <div className="discussion-head">
                        <b>
                          {comment.author_role === "resident"
                            ? comment.author_name || "Resident"
                            : comment.author_name || "InfraTrack Staff"}
                        </b>
                        <small>
                          {comment.created_at
                            ? new Date(comment.created_at).toLocaleString()
                            : "Recently"}
                        </small>
                      </div>
                      <p>{comment.body}</p>
                    </article>
                  ))}
                  {discussionLoading && (
                    <p className="discussion-readonly" role="status">
                      Loading discussion…
                    </p>
                  )}
                  {!discussionLoading && !discussion.length && (
                    <p className="discussion-readonly">
                      No replies yet. Start the official follow-up here.
                    </p>
                  )}
                </div>
                {!discussionLoading && discussion.length > 2 && (
                  <button
                    type="button"
                    className="discussion-toggle"
                    aria-expanded={discussionExpanded}
                    aria-controls="issue-discussion-replies"
                    onClick={() =>
                      setDiscussionExpanded((expanded) => !expanded)
                    }
                  >
                    {discussionExpanded ? (
                      <>
                        <ChevronUp size={15} />
                        Show latest replies
                      </>
                    ) : (
                      <>
                        <ChevronDown size={15} />
                        View all {discussion.length} replies
                      </>
                    )}
                  </button>
                )}
                {discussionError && (
                  <p className="form-error" role="alert">
                    {discussionError}
                  </p>
                )}
                {isReportDiscussionOpen(status) ? (
                  <form
                    className="discussion-reply"
                    onSubmit={postDiscussionReply}
                  >
                    <label htmlFor="report-discussion-reply">
                      Reply as response team
                    </label>
                    <textarea
                      id="report-discussion-reply"
                      value={reply}
                      onChange={(event) => setReply(event.target.value)}
                      maxLength={REPORT_COMMENT_MAX_LENGTH}
                      placeholder="Share a clear progress update or ask the reporter for more details…"
                      rows={3}
                      required
                    />
                    <div className="discussion-reply-footer">
                      <small>
                        {reply.length}/{REPORT_COMMENT_MAX_LENGTH} · Visible to
                        public viewers
                      </small>
                      <button
                        className="primary-button"
                        type="submit"
                        disabled={!reply.trim() || isPostingReply}
                      >
                        <Send size={15} />
                        {isPostingReply ? "Sending…" : "Send reply"}
                      </button>
                    </div>
                  </form>
                ) : (
                  <p className="discussion-readonly">
                    Replies are closed because this report is no longer
                    unresolved.
                  </p>
                )}
              </div>
            </div>
            <div className="modal-section case-management">
              <div className="case-management-heading">
                <h3>Case management</h3>
                <p>Review the AI findings, then set ownership and priority.</p>
              </div>
              <div className="issue-ai-assessment" aria-live="polite">
                <div className="issue-ai-assessment-heading">
                  <span className="issue-ai-icon" aria-hidden="true">
                    <Sparkles size={16} />
                  </span>
                  <div className="issue-ai-title">
                    <b>AI assessment</b>
                    <span>Evidence review</span>
                  </div>
                  <span className="issue-ai-status">
                    <ScanEye size={13} />
                    {data.ai_analysis ? "Analyzed" : "Not available"}
                  </span>
                </div>
                {data.ai_severity && (
                  <div
                    className={`issue-ai-suggestion ${data.ai_severity.toLowerCase()}`}
                  >
                    <span>Suggested severity</span>
                    <b>{data.ai_severity}</b>
                  </div>
                )}
                <p>
                  {data.ai_analysis ||
                    "No AI analysis is saved for this report. It may have been submitted before AI analysis was enabled, or the assessment was unavailable at submission."}
                </p>
                <div className="issue-ai-advisory">
                  <ShieldCheck size={14} aria-hidden="true" />
                  <small>
                    AI is advisory. Review the report and evidence, then set
                    priority below.
                  </small>
                </div>
              </div>
              <label>
                Status
                <select
                  value={status}
                  onChange={(event) => setStatus(event.target.value)}
                >
                  <option>Reported</option>
                  <option>Verified by inspector</option>
                  <option>Rejected</option>
                  <option>In progress</option>
                  <option>Resolved</option>
                </select>
              </label>
              <label>
                Assign to team
                <select
                  value={assigned}
                  onChange={(event) => setAssigned(event.target.value)}
                >
                  <option>Unassigned</option>
                  {assigned !== "Unassigned" &&
                    !(data.teams || []).some(
                      (team) => team.name === assigned,
                    ) && <option value={assigned}>{assigned}</option>}
                  {(data.teams || []).map((team) => (
                    <option key={team.id} value={team.name}>
                      {team.name}
                      {team.department ? ` - ${team.department}` : ""}
                    </option>
                  ))}
                </select>
              </label>
              {status === "In progress" && (
                <>
                  <label className="progress-field">
                    Progress
                    <div className="progress-input-row">
                      <input
                        type="range"
                        min="0"
                        max="100"
                        step="5"
                        value={progressPercentage}
                        onChange={(event) =>
                          setProgressPercentage(Number(event.target.value))
                        }
                      />
                      <output>{progressPercentage}%</output>
                    </div>
                    <div className="progress-track" aria-hidden="true">
                      <span style={{ width: `${progressPercentage}%` }} />
                    </div>
                  </label>
                  <label>
                    Progress update for resident
                    <textarea
                      value={progressNote}
                      maxLength={1000}
                      onChange={(event) => setProgressNote(event.target.value)}
                      placeholder="Describe the work completed or the next action..."
                    />
                    <small>
                      Residents can see this update in their report details.{" "}
                      {progressNote.length}/1,000
                    </small>
                  </label>
                </>
              )}
              <label>
                Admin priority
                <select
                  value={severity}
                  onChange={(event) => setSeverity(event.target.value)}
                >
                  <option>Critical</option>
                  <option>High</option>
                  <option>Medium</option>
                  <option>Low</option>
                </select>
                <small>
                  Set by the admin after reviewing the report and AI assessment.
                </small>
              </label>
              {(status === "Resolved" || status === "Rejected") && (
                <>
                  <label>
                    {status === "Rejected"
                      ? "Rejection reason"
                      : "Resolution note"}
                    <textarea
                      value={note}
                      onChange={(event) => setNote(event.target.value)}
                      placeholder={
                        status === "Rejected"
                          ? "Explain why this report was rejected..."
                          : "Describe what was done..."
                      }
                    />
                  </label>
                </>
              )}
              {status === "Resolved" && (
                <section
                  className="resolution-evidence"
                  aria-label="Before and after photos"
                >
                  <div className="resolution-evidence-heading">
                    <h4>Resolution photos</h4>
                    <span>
                      Compare the reported issue with the completed work.
                    </span>
                  </div>
                  <div className="resolution-evidence-grid">
                    <article className="evidence-card">
                      <div className="evidence-card-heading">
                        <span className="evidence-phase">Before</span>
                        <span className="evidence-source">
                          Resident submission
                        </span>
                      </div>
                      <div
                        className={`evidence-photo-stage${beforePhoto ? " has-photo" : ""}`}
                      >
                        {beforePhoto ? (
                          <img
                            src={beforePhoto}
                            alt="Before: resident-submitted report photo"
                          />
                        ) : (
                          <div className="evidence-empty">
                            <ImageIcon size={22} />
                            <span>No original photo</span>
                          </div>
                        )}
                      </div>
                      <input
                        ref={beforePhotoInput}
                        hidden
                        type="file"
                        accept="image/*"
                        onChange={replaceBeforePhoto}
                      />
                      <button
                        className="evidence-upload-button"
                        type="button"
                        onClick={() => beforePhotoInput.current?.click()}
                        disabled={
                          isUploadingBeforePhoto ||
                          isUploadingAfterPhoto ||
                          isSaving
                        }
                      >
                        <ImageIcon size={15} />
                        {isUploadingBeforePhoto
                          ? "Uploading..."
                          : beforePhoto
                            ? "Replace before photo"
                            : "Add before photo"}
                      </button>
                    </article>
                    <article className="evidence-card">
                      <div className="evidence-card-heading">
                        <span className="evidence-phase after">After</span>
                        <span className="evidence-source">
                          Completion proof
                        </span>
                      </div>
                      <div
                        className={`evidence-photo-stage${afterPhoto ? " has-photo" : ""}`}
                      >
                        {afterPhoto ? (
                          <img
                            src={afterPhoto}
                            alt="After: photo showing completed report resolution"
                          />
                        ) : (
                          <div className="evidence-empty">
                            <ImageIcon size={22} />
                            <span>Add a photo of the completed work</span>
                          </div>
                        )}
                      </div>
                      <input
                        ref={afterPhotoInput}
                        hidden
                        type="file"
                        accept="image/*"
                        onChange={uploadAfterPhoto}
                      />
                      <button
                        className="evidence-upload-button primary"
                        type="button"
                        onClick={() => afterPhotoInput.current?.click()}
                        disabled={
                          isUploadingBeforePhoto ||
                          isUploadingAfterPhoto ||
                          isSaving
                        }
                      >
                        <ImageIcon size={15} />
                        {isUploadingAfterPhoto
                          ? "Uploading..."
                          : afterPhoto
                            ? "Replace after photo"
                            : "Upload after photo"}
                      </button>
                    </article>
                  </div>
                </section>
              )}
            </div>
          </div>
        </div>
        <div className="issue-modal-footer">
          {validationError && (
            <p className="form-error" role="alert">
              {validationError}
            </p>
          )}
          <div className="issue-modal-footer-actions">
            <button
              type="button"
              className="secondary-button danger-button"
              onClick={() =>
                void saveChanges(
                  {
                    status: "Archived",
                    assignedTeam: assigned,
                    resolutionNote: "Archived by administrator",
                  },
                  true,
                )
              }
              disabled={
                isSaving || isUploadingBeforePhoto || isUploadingAfterPhoto
              }
            >
              {isArchiving ? "Archiving..." : "Archive issue"}
            </button>
            <button
              type="button"
              className="primary-button"
              onClick={saveWorkflow}
              disabled={
                isSaving || isUploadingBeforePhoto || isUploadingAfterPhoto
              }
            >
              <CheckCircle2 size={16} />{" "}
              {isSaving ? "Saving..." : "Save changes"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function UserModal({
  user,
  onClose,
  onSave,
  onVerification,
  onFetchReports,
}) {
  const modalRef = useRef(null);
  const closeButtonRef = useRef(null);
  const [standing, setStanding] = useState(user.standing);
  const [selectedAction, setSelectedAction] = useState(null);
  const [reason, setReason] = useState("Spam or duplicate reports");
  const [duration, setDuration] = useState("3 days");
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [verificationSaving, setVerificationSaving] = useState(false);
  const [verificationError, setVerificationError] = useState("");
  const [recentReports, setRecentReports] = useState([]);
  const [reportsLoading, setReportsLoading] = useState(true);
  const [reportsError, setReportsError] = useState("");
  const hasVerificationEvidence = Boolean(user.id_front_url && user.selfie_url);

  useEffect(() => {
    const previousFocus = document.activeElement;
    closeButtonRef.current?.focus();

    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
        return;
      }

      if (event.key !== "Tab") return;
      const focusableElements = modalRef.current?.querySelectorAll(
        'a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])',
      );
      if (!focusableElements?.length) return;

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      if (event.shiftKey && document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      } else if (!event.shiftKey && document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      if (previousFocus instanceof HTMLElement) previousFocus.focus();
    };
  }, [onClose]);

  useEffect(() => {
    let active = true;
    setReportsLoading(true);
    setReportsError("");
    onFetchReports(user.id)
      .then((reports) => {
        if (active) setRecentReports(reports);
      })
      .catch((loadError) => {
        if (active)
          setReportsError(
            loadError.message || "Could not load recent reports.",
          );
      })
      .finally(() => {
        if (active) setReportsLoading(false);
      });
    return () => {
      active = false;
    };
  }, [user.id, onFetchReports]);

  const retryLoadReports = () => {
    setReportsLoading(true);
    setReportsError("");
    onFetchReports(user.id)
      .then(setRecentReports)
      .catch((loadError) =>
        setReportsError(loadError.message || "Could not load recent reports."),
      )
      .finally(() => setReportsLoading(false));
  };

  const chooseAction = (action) => {
    if (selectedAction === action) {
      setSelectedAction(null);
      setError("");
      return;
    }
    setSelectedAction(action);
    setError("");
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

  const reviewVerification = async (decision) => {
    setVerificationSaving(true);
    setVerificationError("");
    try {
      await onVerification?.(decision);
    } catch (reviewError) {
      setVerificationError(
        reviewError.message || "Could not save the verification decision.",
      );
    } finally {
      setVerificationSaving(false);
    }
  };

  return (
    <div className="modal-backdrop user-modal-backdrop" onClick={onClose}>
      <div
        className="modal wide-modal user-detail-modal"
        ref={modalRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="user-modal-title"
        aria-describedby="user-modal-email"
        tabIndex={-1}
        onClick={(event) => event.stopPropagation()}
      >
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
              <h2 id="user-modal-title">{user.name}</h2>
              <p id="user-modal-email" className="user-email">
                {user.email}
              </p>
            </div>
          </div>
          <span
            className={`user-header-standing status ${standing === "Active" ? "resolved" : "pending"}`}
          >
            {standing}
          </span>
          <button
            ref={closeButtonRef}
            type="button"
            className="modal-close user-modal-close"
            aria-label={`Close ${user.name}'s account details`}
            onClick={onClose}
          >
            <X size={18} />
          </button>
        </div>

        <div className="user-modal-scroll-content">
          <div
            className="modal-stats user-meta-row"
            aria-label="Resident account summary"
          >
            <span>
              <MapPin size={15} /> {user.barangay}
            </span>
            <span>
              <FileText size={15} /> {user.reports} reports filed
            </span>
            <span>
              <CalendarDays size={15} /> Joined {user.joined}
            </span>
            <span
              className={`status ${standing === "Active" ? "resolved" : "pending"}`}
            >
              <ShieldCheck size={11} /> {standing}
            </span>
          </div>

          <section
            className="verification-review-panel"
            aria-labelledby="identity-verification-heading"
          >
            <div className="verification-review-heading">
              <div>
                <h3 id="identity-verification-heading">
                  Identity verification
                </h3>
                <p>
                  Compare the government ID front with the live selfie. The ID
                  back is optional.
                </p>
              </div>
              <span
                className={`status ${user.verification === "Verified" ? "verified" : "pending"}`}
              >
                {user.verification || "Pending ID match"}
              </span>
            </div>
            <div className="verification-image-grid">
              <VerificationImage
                label={`${user.id_type || "Government ID"} · front`}
                src={user.id_front_url}
                empty="No ID front submitted"
              />
              <VerificationImage
                label={`${user.id_type || "Government ID"} · back`}
                src={user.id_back_url}
                empty="No ID back submitted"
              />
              <VerificationImage
                label="Live selfie"
                src={user.selfie_url}
                empty="No selfie submitted"
              />
            </div>
            {user.verification === "Verified" ? (
              <div className="verification-decision approved">
                <CheckCircle2 size={16} /> ID and selfie approved
              </div>
            ) : (
              <div className="verification-actions">
                {verificationError && (
                  <p className="verification-error" role="alert">
                    {verificationError}
                  </p>
                )}
                {!hasVerificationEvidence && (
                  <p className="verification-evidence-warning" role="status">
                    An ID front and live selfie are required before this account
                    can be approved.
                  </p>
                )}
                <button
                  type="button"
                  className="verification-reject-button"
                  disabled={verificationSaving}
                  onClick={() => reviewVerification("reject")}
                >
                  <Ban size={15} /> Reject ID
                </button>
                <button
                  type="button"
                  className="verification-approve-button"
                  disabled={verificationSaving || !hasVerificationEvidence}
                  title={
                    !hasVerificationEvidence
                      ? "An ID front and live selfie are required for approval"
                      : undefined
                  }
                  onClick={() => reviewVerification("approve")}
                >
                  <CheckCircle2 size={15} />{" "}
                  {verificationSaving ? "Saving..." : "Approve ID"}
                </button>
              </div>
            )}
          </section>

          <div className="user-modal-content">
            <div className="user-left-panel">
              <h3
                id="resident-reports-heading"
                className="report-section-title"
              >
                Recent reports
              </h3>

              <div
                className="report-list"
                aria-labelledby="resident-reports-heading"
              >
                {reportsLoading ? (
                  <p className="recent-reports-message">
                    Loading recent reports...
                  </p>
                ) : reportsError ? (
                  <p className="recent-reports-message error" role="alert">
                    {reportsError}{" "}
                    <button type="button" onClick={retryLoadReports}>
                      Retry
                    </button>
                  </p>
                ) : recentReports.length === 0 ? (
                  <div className="user-modal-empty-state">
                    <FileText size={17} aria-hidden="true" />
                    <span>This resident has not filed any reports.</span>
                  </div>
                ) : (
                  recentReports.map((report) => (
                    <div className="mini-report" key={report.public_id}>
                      <span className="report-icon">
                        <FileText size={13} />
                      </span>
                      <div>
                        <b>{report.title}</b>
                        <small>
                          #{report.public_id} · {report.category} ·{" "}
                          {new Date(report.created_at).toLocaleDateString()}
                        </small>
                      </div>
                    </div>
                  ))
                )}
              </div>

              <div className="moderation-box">
                <h3>Moderation history</h3>
                <div className="user-modal-empty-state compact">
                  <Clock3 size={16} aria-hidden="true" />
                  <span>No moderation actions on record.</span>
                </div>
              </div>
            </div>

            <div className="user-right-panel">
              <h3 id="trust-safety-heading" className="trust-title">
                Trust &amp; safety
              </h3>

              <section
                className="safety-card-wrap"
                aria-labelledby="trust-safety-heading"
              >
                <div className="safety-card">
                  <div className="safety-card-header">ACCOUNT STANDING</div>
                  <p className="safety-note">
                    {standing === "Banned"
                      ? "This account is banned and cannot sign in."
                      : standing === "Suspended"
                        ? user.suspended_until
                          ? `Report submissions are suspended until ${new Date(user.suspended_until).toLocaleString()}.`
                          : "Report submissions are suspended until an administrator restores access."
                        : "This account is active. Warnings are informational and do not restrict account access."}
                  </p>

                  <div className="safety-actions">
                    {standing !== "Banned" && (
                      <>
                        <button
                          type="button"
                          className={
                            selectedAction === "warn" ? "selected" : ""
                          }
                          aria-pressed={selectedAction === "warn"}
                          disabled={saving}
                          onClick={() => chooseAction("warn")}
                        >
                          <AlertTriangle size={15} /> Warn
                        </button>
                        <button
                          type="button"
                          className={
                            selectedAction === "suspend" ? "selected" : ""
                          }
                          aria-pressed={selectedAction === "suspend"}
                          disabled={saving}
                          onClick={() => chooseAction("suspend")}
                        >
                          <Clock3 size={15} /> Suspend
                        </button>
                        <button
                          type="button"
                          className={`ban-button ${selectedAction === "ban" ? "selected" : ""}`}
                          aria-pressed={selectedAction === "ban"}
                          disabled={saving}
                          onClick={() => chooseAction("ban")}
                        >
                          <Ban size={15} /> Ban
                        </button>
                      </>
                    )}
                    {standing !== "Active" && (
                      <button
                        type="button"
                        className={
                          selectedAction === "restore" ? "selected" : ""
                        }
                        aria-pressed={selectedAction === "restore"}
                        disabled={saving}
                        onClick={() => chooseAction("restore")}
                      >
                        <CheckCircle2 size={15} /> Restore
                      </button>
                    )}
                  </div>

                  {selectedAction && (
                    <div className="selected-action-block">
                      <label>
                        Reason
                        <select
                          value={reason}
                          onChange={(event) => setReason(event.target.value)}
                        >
                          <option>Spam or duplicate reports</option>
                          <option>Abusive or threatening language</option>
                          <option>Fraudulent account activity</option>
                        </select>
                      </label>
                      {selectedAction === "suspend" && (
                        <label>
                          Reporting restriction
                          <select
                            value={duration}
                            onChange={(event) =>
                              setDuration(event.target.value)
                            }
                          >
                            <option>24 hours</option>
                            <option>3 days</option>
                            <option>7 days</option>
                            <option>14 days</option>
                            <option>30 days</option>
                            <option>Permanent</option>
                          </select>
                        </label>
                      )}
                      <p className="safety-note">
                        {selectedAction === "warn"
                          ? "A warning sends a notice only. The account remains active."
                          : selectedAction === "suspend"
                            ? "Suspension prevents report submissions for the selected period. Other app features remain available."
                            : selectedAction === "ban"
                              ? "A ban signs the resident out and prevents future sign-in until access is restored."
                              : "Restore this resident’s account and report-submission access."}
                      </p>
                      <label>
                        Note
                        <textarea
                          value={note}
                          onChange={(event) => setNote(event.target.value)}
                        />
                      </label>
                      {error && (
                        <p className="login-error" role="alert">
                          {error}
                        </p>
                      )}
                      <button
                        className={`primary-button full-button ${selectedAction}-action`}
                        onClick={() =>
                          apply(
                            selectedAction === "suspend"
                              ? "Suspended"
                              : selectedAction === "ban"
                                ? "Banned"
                                : selectedAction === "restore"
                                  ? "Active"
                                  : standing,
                          )
                        }
                        disabled={saving}
                      >
                        {saving
                          ? "Saving..."
                          : selectedAction === "restore"
                            ? "Restore account"
                            : selectedAction === "ban"
                              ? "Ban account"
                              : selectedAction === "suspend"
                                ? "Suspend reporting"
                                : "Send warning"}
                      </button>
                    </div>
                  )}
                </div>

                <p className="safety-footer">
                  Warnings are notice-only. Suspensions restrict report
                  submissions for the selected period; bans block sign-in until
                  restored. Every action is recorded and the resident is
                  notified.
                </p>
              </section>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function VerificationImage({ label, src, empty }) {
  return (
    <div className="verification-image-card">
      <strong>{label}</strong>
      <div className="verification-image-frame">
        {src ? (
          <a href={src} target="_blank" rel="noreferrer">
            <img src={src} alt={`${label} submitted for verification`} />
          </a>
        ) : (
          <span>{empty}</span>
        )}
      </div>
      {src && <small>Open full image</small>}
    </div>
  );
}
