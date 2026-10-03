import { useEffect, useRef, useState } from "react";
import {
  AlertTriangle,
  Camera,
  CheckCircle2,
  Megaphone,
  Pencil,
  Send,
  Trash2,
  Video,
  Wrench,
  X,
} from "lucide-react";
import { API_BASE, apiFetch } from "../api";

const typeMeta = {
  alert: ["Emergency alert", AlertTriangle],
  maint: ["Maintenance", Wrench],
  gen: ["Announcement", Megaphone],
};

export default function AdvisoryPage({ publishedOnly = false, onViewAll, user }) {
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [type, setType] = useState("alert");
  const [media, setMedia] = useState(null);
  const [audience, setAudience] = useState("All barangays");
  const [published, setPublished] = useState(false);
  const [advisories, setAdvisories] = useState([]);
  const [editingAdvisory, setEditingAdvisory] = useState(null);
  const [error, setError] = useState("");
  const [convertingExisting, setConvertingExisting] = useState(false);
  const [convertingNew, setConvertingNew] = useState(false);
  const photoInput = useRef(null);
  const videoInput = useRef(null);
  const editPhotoInput = useRef(null);
  const editVideoInput = useRef(null);

  const uploadMedia = async (file, target) => {
    if (!file) return;
    try {
      const formData = new FormData();
      formData.append("file", file);
      const response = await apiFetch(`/uploads`, { method: "POST", body: formData });
      const rawText = await response.text();
      const contentType = response.headers.get("content-type") || "";
      let data = null;

      if (rawText.trim()) {
        try {
          if (contentType.includes("application/json") || rawText.trim().startsWith("{") || rawText.trim().startsWith("[")) {
            data = JSON.parse(rawText);
          }
        } catch {
          // Ignore JSON parse failures here and fall back to an explicit user-facing error below.
        }
      }

      if (!response.ok) {
        const serverMessage = data?.error || rawText.trim() || "Could not upload media.";
        throw new Error(serverMessage.length > 220 ? `${serverMessage.slice(0, 220)}…` : serverMessage);
      }

      if (!data && rawText.trim()) {
        throw new Error("The upload request returned an unexpected response. Please try a different or smaller file.");
      }

      if (!data?.url) {
        throw new Error("The upload request did not include a file URL. Please try again.");
      }

      const uploaded = { kind: data.mediaKind, src: data.url };
      if (target === "edit") setEditingAdvisory((current) => ({ ...current, draftMedia: uploaded }));
      else setMedia(uploaded);
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : "Could not upload media.");
    }
  };

  const convertNewVideo = async () => {
    if (media?.kind !== "video") return;
    setConvertingNew(true);
    setError("");
    try {
      const response = await apiFetch(`/uploads/convert-gif`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url: media.src }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not convert video to GIF");
      setMedia({ kind: "gif", src: data.url });
    } catch (conversionError) {
      setError(conversionError.message === "Failed to fetch"
        ? "The conversion service is unavailable. Please make sure the InfraTrack API is running, then try again."
        : conversionError.message);
    } finally {
      setConvertingNew(false);
    }
  };

  const loadAdvisories = async () => {
    const response = await apiFetch(`/advisories?userId=${encodeURIComponent(user?.id || "")}`);
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Could not load advisories");
    setAdvisories(data.advisories ?? []);
  };

  useEffect(() => {
    loadAdvisories().catch((loadError) => setError(loadError.message));
  }, [user?.id]);

  useEffect(() => {
    if (!published) return;
    const timeoutId = window.setTimeout(() => setPublished(false), 2500);
    return () => window.clearTimeout(timeoutId);
  }, [published]);

  const publish = async () => {
    if (!title.trim() || !message.trim()) return;
    setError("");
    setPublished(false);
    try {
      const response = await apiFetch(`/advisories`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type, title, message, audience, barangay: user?.barangay, mediaUrl: media?.src, mediaKind: media?.kind, adminId: user?.id }),
      });
      if (!response.ok) throw new Error("Could not publish advisory");
      await loadAdvisories();
      setTitle(""); setMessage(""); setMedia(null); setPublished(true);
    } catch (publishError) {
      setError(publishError.message === "Failed to fetch"
        ? "The API is unavailable. Please restart the InfraTrack backend and try again."
        : publishError.message);
    }
  };

  const openEdit = (advisory) => {
    setEditingAdvisory({
      ...advisory,
      draftTitle: advisory.title,
      draftMessage: advisory.message,
      draftType: advisory.type,
      draftMedia: advisory.media || (advisory.media_url
        ? { kind: advisory.media_kind, src: advisory.media_url }
        : null),
    });
  };

  const saveEdit = async () => {
    if (!editingAdvisory) return;
    if (!editingAdvisory.draftTitle.trim() || !editingAdvisory.draftMessage.trim()) {
      return;
    }

    try {
      const response = await apiFetch(`/advisories/${editingAdvisory.id}`, {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type: editingAdvisory.draftType, title: editingAdvisory.draftTitle, message: editingAdvisory.draftMessage, barangay: user?.barangay, mediaUrl: editingAdvisory.draftMedia?.src, mediaKind: editingAdvisory.draftMedia?.kind, adminId: user?.id }),
      });
      if (!response.ok) throw new Error("Could not save advisory");
      await loadAdvisories(); setEditingAdvisory(null);
    } catch (saveError) { setError(saveError.message); }
  };

  const convertExistingVideo = async () => {
    if (!editingAdvisory || editingAdvisory.draftMedia?.kind !== "video") return;
    setConvertingExisting(true);
    setError("");
    try {
      const response = await apiFetch(`/advisories/${editingAdvisory.id}/convert-gif`, { method: "POST" });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not convert video to GIF");
      setEditingAdvisory((current) => ({ ...current, draftMedia: { kind: "gif", src: data.url } }));
      await loadAdvisories();
    } catch (conversionError) {
      setError(conversionError.message);
    } finally {
      setConvertingExisting(false);
    }
  };

  const deleteAdvisory = async (advisoryId) => {
    try {
      const adminId = JSON.parse(localStorage.getItem("infratrack.adminUser") || "null")?.id;
      const response = await apiFetch(`/advisories/${advisoryId}?adminId=${encodeURIComponent(adminId || "")}`, { method: "DELETE" });
      if (!response.ok) throw new Error("Could not archive advisory");
      await loadAdvisories(); setEditingAdvisory(null);
    } catch (deleteError) { setError(deleteError.message); }
  };

  const displayedAdvisories = publishedOnly ? advisories : advisories.slice(0, 2);
  const hasVideoPendingConversion = media?.kind === "video";

  return (
    <div className={`advisory-grid ${publishedOnly ? "published-advisory-page" : ""}`}>
      {!publishedOnly && <article className="card form-card">
        <div className="card-head">
          <h2>New advisory</h2>
        </div>
        <label>Advisory type</label>
        <div className="type-picker">
          <button type="button" className={type === "alert" ? "selected alert" : "alert"} onClick={() => setType("alert")}>
            <AlertTriangle size={16} strokeWidth={2.2} /> Emergency
          </button>
          <button type="button" className={type === "maint" ? "selected maint" : "maint"} onClick={() => setType("maint")}>
            <Wrench size={16} strokeWidth={2.2} /> Maintenance
          </button>
          <button type="button" className={type === "gen" ? "selected gen" : "gen"} onClick={() => setType("gen")}>
            <Megaphone className="announcement-icon" size={17} strokeWidth={2.4} /> Announcement
          </button>
        </div>
        <label>Title</label>
        <input
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder="e.g. Flash flood advisory"
        />
        <label>Message</label>
        <textarea
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          placeholder="Describe the advisory, affected area, and duration…"
        />
        <label>Attach media (optional)</label>
        <div className="media-picker">
          <button
            type="button"
            className={media?.kind === "photo" ? "attached" : ""}
            onClick={() => photoInput.current?.click()}
          >
            <Camera size={16} /> Add photo
          </button>
          <button
            type="button"
            className={media?.kind === "video" || media?.kind === "gif" ? "attached" : ""}
            onClick={() => videoInput.current?.click()}
          >
            <Video size={16} /> Add video
          </button>
        </div>
        <input ref={photoInput} hidden type="file" accept="image/*" onChange={(event) => uploadMedia(event.target.files?.[0], "new")} />
        <input ref={videoInput} hidden type="file" accept="video/*,.gif" onChange={(event) => uploadMedia(event.target.files?.[0], "new")} />
        {media && (
          <div className="advisory-media-preview">
            {media.kind === "video" ? <video src={media.src} controls /> : <img src={media.src} alt="Attached advisory media" />}
            <button type="button" onClick={() => setMedia(null)}><X size={14} /></button>
            <span>
              {media.kind === "gif" ? "GIF preview" : media.kind === "video" ? "Video attached" : "Photo attached"}
            </span>
          </div>
        )}
        {media?.kind === "video" && (
          <button type="button" className="secondary-button advisory-convert-button" onClick={convertNewVideo} disabled={convertingNew}>
            <Video size={16} /> {convertingNew ? "Converting…" : "Convert video to GIF"}
          </button>
        )}
        <label>Audience</label>
        <select value={audience} onChange={(event) => setAudience(event.target.value)}>
          <option>All barangays</option>
          <option>Brgy. Central</option>
          <option>Brgy. Dawan</option>
          <option>Brgy. Sainz</option>
          <option>Brgy. Matiao</option>
          <option>Brgy. Dahican</option>
        </select>
        <button type="button" className="primary-button" onClick={publish}>
          <Send size={16} /> Publish advisory
        </button>
        {published && (
          <div className="success-note">
            <CheckCircle2 size={16} /> Advisory ready for the citizen feed.
          </div>
        )}
        {error && <div className="login-error" role="alert">{error}</div>}
      </article>}

      <article className={`card ${publishedOnly ? "published-advisory-list" : ""}`}>
        <div className="card-head">
          <h2>{publishedOnly ? "All published advisories" : "Published advisories"}</h2>
          {publishedOnly ? (
            <span className="muted">{advisories.length} published</span>
          ) : (
            <button type="button" className="text-link" onClick={onViewAll}>View all <span aria-hidden="true">→</span></button>
          )}
        </div>
        <div className={publishedOnly ? "published-advisory-cards" : ""}>
        {displayedAdvisories.map((advisory) => {
          const [label, AdvisoryIcon] = typeMeta[advisory.type];
          return (
            <div className={`advisory-card ${advisory.type}`} key={advisory.id}>
              {(advisory.media || advisory.media_url) && (
                <div className="advisory-card-media">
                  {(advisory.media?.kind || advisory.media_kind) === "video"
                    ? <video src={advisory.media?.src || advisory.media_url} controls />
                    : <img src={advisory.media?.src || advisory.media_url} alt="" />}
                  <span>{(advisory.media?.kind || advisory.media_kind) === "gif" ? "GIF" : (advisory.media?.kind || advisory.media_kind) === "video" ? "VIDEO" : "PHOTO"}</span>
                </div>
              )}
              <div className="advisory-tag">
                <AdvisoryIcon size={12} strokeWidth={2.4} /> {label}
              </div>
              <h3>{advisory.title}</h3>
              <p>{advisory.message}</p>
              <div className="advisory-card-footer">
                <small>{advisory.created_at ? new Date(advisory.created_at).toLocaleString() : "Recently issued"}</small>
                <span>
                  <button type="button" onClick={() => openEdit(advisory)}><Pencil size={14} /></button>
                  <button type="button" onClick={() => deleteAdvisory(advisory.id)}><Trash2 size={14} /></button>
                </span>
              </div>
            </div>
          );
        })}
        </div>
      </article>

      {editingAdvisory && (
        <div className="modal-backdrop" onClick={() => setEditingAdvisory(null)}>
          <div className="modal advisory-editor-modal" onClick={(event) => event.stopPropagation()}>
            <button className="modal-close" onClick={() => setEditingAdvisory(null)}>
              <X size={18} />
            </button>
            <div className="advisory-edit-header">
              <h2>Edit advisory</h2>
              <p>Changes are visible to citizens immediately after saving.</p>
            </div>

            <label>Advisory type</label>
            <div className="type-picker advisory-edit-picker">
              <button type="button" className={editingAdvisory.draftType === "alert" ? "selected alert" : "alert"} onClick={() => setEditingAdvisory((current) => ({ ...current, draftType: "alert" }))}>
                <AlertTriangle size={16} strokeWidth={2.2} /> Emergency
              </button>
              <button type="button" className={editingAdvisory.draftType === "maint" ? "selected maint" : "maint"} onClick={() => setEditingAdvisory((current) => ({ ...current, draftType: "maint" }))}>
                <Wrench size={16} strokeWidth={2.2} /> Maintenance
              </button>
              <button type="button" className={editingAdvisory.draftType === "gen" ? "selected gen" : "gen"} onClick={() => setEditingAdvisory((current) => ({ ...current, draftType: "gen" }))}>
                <Megaphone size={17} strokeWidth={2.4} /> Announcement
              </button>
            </div>

            <label>Title</label>
            <input
              value={editingAdvisory.draftTitle}
              onChange={(event) =>
                setEditingAdvisory((current) => ({ ...current, draftTitle: event.target.value }))
              }
            />

            <label>Message</label>
            <textarea
              value={editingAdvisory.draftMessage}
              onChange={(event) =>
                setEditingAdvisory((current) => ({ ...current, draftMessage: event.target.value }))
              }
            />

            <label>Attached media</label>
            <div className="media-picker">
              <button
                type="button"
                className={editingAdvisory.draftMedia?.kind === "photo" ? "attached" : ""}
                onClick={() => editPhotoInput.current?.click()}
              >
                <Camera size={16} /> Add photo
              </button>
              <button
                type="button"
                className={editingAdvisory.draftMedia?.kind === "gif" || editingAdvisory.draftMedia?.kind === "video" ? "attached" : ""}
                onClick={() => editVideoInput.current?.click()}
              >
                <Video size={16} /> Add video
              </button>
            </div>

            <input ref={editPhotoInput} hidden type="file" accept="image/*" onChange={(event) => uploadMedia(event.target.files?.[0], "edit")} />
            <input ref={editVideoInput} hidden type="file" accept="video/*,.gif" onChange={(event) => uploadMedia(event.target.files?.[0], "edit")} />

            {editingAdvisory.draftMedia && (
              <div className="advisory-media-preview advisory-edit-preview">
                {editingAdvisory.draftMedia.kind === "video" ? <video src={editingAdvisory.draftMedia.src} controls /> : <img src={editingAdvisory.draftMedia.src} alt="Attached advisory media" />}
                <button type="button" onClick={() => setEditingAdvisory((current) => ({ ...current, draftMedia: null }))}><X size={14} /></button>
                <span>
                  {editingAdvisory.draftMedia.kind === "gif"
                    ? "GIF preview"
                    : editingAdvisory.draftMedia.kind === "video"
                      ? "Video attached"
                      : "Photo attached"}
                </span>
              </div>
            )}
            {editingAdvisory.draftMedia?.kind === "video" && (
              <button type="button" className="secondary-button advisory-convert-button" onClick={convertExistingVideo} disabled={convertingExisting}>
                <Video size={16} /> {convertingExisting ? "Converting…" : "Convert existing video to GIF"}
              </button>
            )}

            <div className="advisory-edit-actions">
              <button type="button" className="secondary-button danger-button" onClick={() => deleteAdvisory(editingAdvisory.id)}>
                <Trash2 size={16} /> Delete
              </button>
              <button type="button" className="primary-button" onClick={saveEdit}>
                <CheckCircle2 size={16} /> Save changes
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
