import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import {
  Camera,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Image,
  Heart,
  Megaphone,
  MapPin,
  MessageCircle,
  Pencil,
  Send,
  Trash2,
  Video,
  Wrench,
  X,
} from "lucide-react";
import { API_BASE, apiFetch } from "../api";
import {
  applyNewsCarouselSelection,
  getAdvisoryAudience,
  getNewsCarouselFeaturedCount,
  getFeaturedNewsCarouselAdvisories,
  isNewsCarouselFeatured,
  mergeCreatedAdvisory,
  resolveConfirmedNewsCarouselSelection,
  validateAdvisoryDraft,
  validateNewsCarouselFeature,
} from "../advisoryForm";

const ADVISORIES_PER_PAGE = 6;

async function createVideoNotificationThumbnail(file) {
  const video = document.createElement("video");
  const objectUrl = URL.createObjectURL(file);
  video.muted = true;
  video.preload = "metadata";
  video.src = objectUrl;

  try {
    await new Promise((resolve, reject) => {
      video.onloadeddata = resolve;
      video.onerror = () =>
        reject(new Error("Could not read a frame from this video."));
    });
    const scale = Math.min(1, 640 / video.videoWidth);
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(video.videoWidth * scale));
    canvas.height = Math.max(1, Math.round(video.videoHeight * scale));
    const context = canvas.getContext("2d");
    if (!context) throw new Error("Could not create a video preview.");

    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    const radius = Math.max(20, Math.min(canvas.width, canvas.height) * 0.13);
    context.fillStyle = "rgba(0, 0, 0, 0.58)";
    context.beginPath();
    context.arc(centerX, centerY, radius, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = "#ffffff";
    context.beginPath();
    context.moveTo(centerX - radius * 0.28, centerY - radius * 0.48);
    context.lineTo(centerX + radius * 0.5, centerY);
    context.lineTo(centerX - radius * 0.28, centerY + radius * 0.48);
    context.closePath();
    context.fill();

    return await new Promise((resolve, reject) => {
      canvas.toBlob(
        (blob) =>
          blob
            ? resolve(
                new File([blob], "video-notification.jpg", {
                  type: "image/jpeg",
                }),
              )
            : reject(new Error("Could not encode the video preview.")),
        "image/jpeg",
        0.82,
      );
    });
  } finally {
    URL.revokeObjectURL(objectUrl);
    video.removeAttribute("src");
    video.load();
  }
}

const typeMeta = {
  alert: ["Advertisement", Image],
  advertisement: ["Advertisement", Image],
  maint: ["Maintenance", Wrench],
  gen: ["Announcement", Megaphone],
};

export default function AdvisoryPage({
  publishedOnly = false,
  onNotify,
  onViewAll,
  onViewEngagement,
  user,
}) {
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [type, setType] = useState("advertisement");
  const [media, setMedia] = useState(null);
  const [featuredInNews, setFeaturedInNews] = useState(false);
  const [audience, setAudience] = useState("All barangays");
  const [published, setPublished] = useState(false);
  const [isPublishing, setIsPublishing] = useState(false);
  const [advisories, setAdvisories] = useState([]);
  const [advisoryPage, setAdvisoryPage] = useState(1);
  const [isLoadingAdvisories, setIsLoadingAdvisories] = useState(true);
  const [editingAdvisory, setEditingAdvisory] = useState(null);
  const [error, setError] = useState("");
  const [archivingAdvisoryId, setArchivingAdvisoryId] = useState(null);
  const [savingCarouselAdvisoryId, setSavingCarouselAdvisoryId] = useState(null);
  const [convertingExisting, setConvertingExisting] = useState(false);
  const [convertingNew, setConvertingNew] = useState(false);
  const [uploadingMedia, setUploadingMedia] = useState(null);
  const photoInput = useRef(null);
  const videoInput = useRef(null);
  const publishInFlight = useRef(false);
  const editPhotoInput = useRef(null);
  const editVideoInput = useRef(null);

  const uploadMedia = async (file, target) => {
    if (!file) return;
    const kind = file.type.startsWith("video/") || /\.gif$/i.test(file.name)
      ? "video"
      : "image";
    setUploadingMedia({ target, kind, name: file.name });
    setError("");
    try {
      const formData = new FormData();
      formData.append("file", file);
      if (file.type.startsWith("video/")) {
        formData.append("thumbnail", await createVideoNotificationThumbnail(file));
      }
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

      const uploaded = {
        kind: data.mediaKind,
        src: data.url,
        thumbnailUrl: data.thumbnailUrl || null,
      };
      if (target === "edit") setEditingAdvisory((current) => ({ ...current, draftMedia: uploaded }));
      else setMedia(uploaded);
      onNotify?.(`${kind === "video" ? "Video" : "Image"} uploaded.`);
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : "Could not upload media.");
    } finally {
      setUploadingMedia(null);
    }
  };

  const convertNewVideo = async () => {
    if (media?.kind !== "video") return;
    setConvertingNew(true);
    setError("");
    let lastConversionError = null;
    try {
      for (let attempt = 0; attempt < 2; attempt += 1) {
        const controller = new AbortController();
        const timeoutId = window.setTimeout(() => controller.abort(), 180000);
        try {
          const response = await apiFetch(`/uploads/convert-gif`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ url: media.src }),
            signal: controller.signal,
          });
          const rawText = await response.text();
          let data = null;
          if (rawText.trim()) {
            try {
              data = JSON.parse(rawText);
            } catch {
              throw new Error(rawText.includes("Bad Request")
                ? "The conversion request was rejected. Please upload the video again and retry."
                : "The conversion service returned an invalid response.");
            }
          }
          if (!response.ok) throw new Error(data?.error || "Could not convert video to GIF");
          if (!data?.url) throw new Error("The conversion service did not return a converted GIF.");
          setMedia({ kind: "gif", src: data.url });
          return;
        } catch (conversionError) {
          lastConversionError = conversionError;
        } finally {
          window.clearTimeout(timeoutId);
        }
        if (attempt === 0) await new Promise((resolve) => window.setTimeout(resolve, 1500));
      }
      throw lastConversionError || new Error("Could not convert video to GIF");
    } catch (conversionError) {
      const timedOut = conversionError.name === "AbortError";
      setError(timedOut
        ? "Video conversion timed out. Please try again with a shorter video."
        : conversionError.message === "Failed to fetch"
        ? "The conversion service is unavailable. Please make sure the InfraTrack API is running, then try again."
        : conversionError.message);
    } finally {
      setConvertingNew(false);
    }
  };

  const loadAdvisories = async (showLoading = false) => {
    if (showLoading) setIsLoadingAdvisories(true);
    try {
      const response = await apiFetch(`/advisories?userId=${encodeURIComponent(user?.id || "")}`);
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not load advisories");
      setAdvisories(data.advisories ?? []);
    } finally {
      if (showLoading) setIsLoadingAdvisories(false);
    }
  };

  useEffect(() => {
    loadAdvisories(true).catch((loadError) => setError(loadError.message));
  }, [user?.id]);

  useEffect(() => {
    if (!published) return;
    const timeoutId = window.setTimeout(() => setPublished(false), 2500);
    return () => window.clearTimeout(timeoutId);
  }, [published]);

  const totalAdvisoryPages = Math.max(
    1,
    Math.ceil(advisories.length / ADVISORIES_PER_PAGE),
  );
  const currentAdvisoryPage = Math.min(advisoryPage, totalAdvisoryPages);

  useEffect(() => {
    if (advisoryPage > totalAdvisoryPages) {
      setAdvisoryPage(totalAdvisoryPages);
    }
  }, [advisoryPage, totalAdvisoryPages]);

  const publish = async () => {
    if (publishInFlight.current) return;
    const validationError = validateAdvisoryDraft(title, message);
    if (validationError) {
      setError(validationError);
      return;
    }
    const carouselError = validateNewsCarouselFeature({
      featuredInNews: canManageNewsCarousel && featuredInNews,
      featuredCount,
      mediaKind: media?.kind,
      mediaUrl: media?.src,
    });
    if (carouselError) {
      setError(carouselError);
      return;
    }
    setError("");
    setPublished(false);
    publishInFlight.current = true;
    setIsPublishing(true);
    try {
      const response = await apiFetch(`/advisories`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type, title, message, audience: getAdvisoryAudience(user, audience), barangay: user?.barangay, mediaUrl: media?.src, mediaKind: media?.kind, mediaThumbnailUrl: media?.thumbnailUrl, featuredInNews: canManageNewsCarousel && featuredInNews }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not publish advisory");
      if (data.advisory) {
        setAdvisories((current) =>
          mergeCreatedAdvisory(current, data.advisory, {
            mediaUrl: media?.src,
            mediaKind: media?.kind,
          }),
        );
      }
      await loadAdvisories();
      setTitle(""); setMessage(""); setMedia(null); setFeaturedInNews(false); setPublished(true);
    } catch (publishError) {
      setError(publishError.message === "Failed to fetch"
        ? "The API is unavailable. Please restart the InfraTrack backend and try again."
        : publishError.message);
    } finally {
      publishInFlight.current = false;
      setIsPublishing(false);
    }
  };

  const openEdit = (advisory) => {
    setError("");
    setEditingAdvisory({
      ...advisory,
      draftTitle: advisory.title,
      draftMessage: advisory.message,
      draftType: advisory.type === "alert" ? "advertisement" : advisory.type,
      featured_in_news: isNewsCarouselFeatured(advisory.featured_in_news),
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
    const carouselError = validateNewsCarouselFeature({
      featuredInNews: editingAdvisory.featured_in_news,
      featuredCount,
      alreadyFeatured: isNewsCarouselFeatured(
        advisories.find((advisory) => advisory.id === editingAdvisory.id)
          ?.featured_in_news,
      ),
      mediaKind: editingAdvisory.draftMedia?.kind,
      mediaUrl: editingAdvisory.draftMedia?.src,
    });
    if (carouselError) {
      setError(carouselError);
      return;
    }

    try {
      const response = await apiFetch(`/advisories/${editingAdvisory.id}`, {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          type: editingAdvisory.draftType,
          title: editingAdvisory.draftTitle,
          message: editingAdvisory.draftMessage,
          mediaUrl: editingAdvisory.draftMedia?.src,
          mediaKind: editingAdvisory.draftMedia?.kind,
          ...(canManageNewsCarousel
            ? { featuredInNews: editingAdvisory.featured_in_news }
            : {}),
        }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not save advisory");
      await loadAdvisories(); setEditingAdvisory(null); setError("");
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
    if (archivingAdvisoryId !== null) return;
    setArchivingAdvisoryId(advisoryId);
    try {
      const response = await apiFetch(`/advisories/${advisoryId}`, { method: "DELETE" });
      if (!response.ok) throw new Error("Could not archive advisory");
      await loadAdvisories();
      setEditingAdvisory(null);
      onNotify?.("Advisory archived.");
    } catch (deleteError) {
      setError(deleteError.message);
    } finally {
      setArchivingAdvisoryId(null);
    }
  };

  const setPublishedNewsCarousel = async (advisory, featuredInNews) => {
    const carouselError = validateNewsCarouselFeature({
      featuredInNews,
      featuredCount,
      alreadyFeatured: isNewsCarouselFeatured(advisory.featured_in_news),
      mediaKind: advisory.media?.kind || advisory.media_kind,
      mediaUrl: advisory.media?.src || advisory.media_url,
    });
    if (carouselError) {
      setError(carouselError);
      return;
    }

    setSavingCarouselAdvisoryId(advisory.id);
    setError("");
    const previousFeatured = isNewsCarouselFeatured(advisory.featured_in_news);
    setAdvisories((current) =>
      applyNewsCarouselSelection(current, advisory.id, featuredInNews),
    );
    try {
      const response = await apiFetch(`/advisories/${advisory.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ featuredInNews }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not update the News carousel");
      const confirmedFeatured = resolveConfirmedNewsCarouselSelection(
        data.advisory,
        featuredInNews,
      );
      setAdvisories((current) =>
        applyNewsCarouselSelection(current, advisory.id, confirmedFeatured),
      );
      onNotify?.(featuredInNews
        ? "Added to the News carousel."
        : "Removed from the News carousel.");
    } catch (carouselSaveError) {
      setAdvisories((current) =>
        applyNewsCarouselSelection(current, advisory.id, previousFeatured),
      );
      setError(carouselSaveError.message);
    } finally {
      setSavingCarouselAdvisoryId(null);
    }
  };

  const displayedAdvisories = publishedOnly
    ? advisories.slice(
        (currentAdvisoryPage - 1) * ADVISORIES_PER_PAGE,
        currentAdvisoryPage * ADVISORIES_PER_PAGE,
      )
    : advisories.slice(0, 2);
  const firstVisibleAdvisory = advisories.length
    ? (currentAdvisoryPage - 1) * ADVISORIES_PER_PAGE + 1
    : 0;
  const lastVisibleAdvisory = publishedOnly
    ? Math.min(currentAdvisoryPage * ADVISORIES_PER_PAGE, advisories.length)
    : displayedAdvisories.length;
  const hasVideoPendingConversion = media?.kind === "video";
  const canManageNewsCarousel = user?.role === "lgu";
  const featuredCount = getNewsCarouselFeaturedCount(advisories);
  const featuredCarouselAdvisories = getFeaturedNewsCarouselAdvisories(advisories);

  return (
    <div className={`advisory-grid ${publishedOnly ? "published-advisory-page" : ""}`}>
      {!publishedOnly && <article className="card form-card advisory-composer">
        <div className="card-head">
          <div className="advisory-panel-heading">
            <h2>New advisory</h2>
            <p>Share a clear update with the selected residents.</p>
          </div>
        </div>
        <label>Advisory type</label>
        <div className="type-picker" role="group" aria-label="Advisory type">
          <button type="button" aria-pressed={type === "advertisement"} className={type === "advertisement" ? "selected advertisement" : "advertisement"} onClick={() => setType("advertisement")}>
            <Image size={16} strokeWidth={2.2} /> Advertisement
          </button>
          <button type="button" aria-pressed={type === "maint"} className={type === "maint" ? "selected maint" : "maint"} onClick={() => setType("maint")}>
            <Wrench size={16} strokeWidth={2.2} /> Maintenance
          </button>
          <button type="button" aria-pressed={type === "gen"} className={type === "gen" ? "selected gen" : "gen"} onClick={() => setType("gen")}>
            <Megaphone className="announcement-icon" size={17} strokeWidth={2.4} /> Announcement
          </button>
        </div>
        <label htmlFor="advisory-title">Title</label>
        <input
          id="advisory-title"
          required
          aria-invalid={Boolean(error && !title.trim())}
          value={title}
          onChange={(event) => { setTitle(event.target.value); setError(""); }}
          placeholder="e.g. Flash flood advisory"
        />
        <label htmlFor="advisory-message">Message</label>
        <textarea
          id="advisory-message"
          required
          aria-invalid={Boolean(error && !message.trim())}
          value={message}
          onChange={(event) => { setMessage(event.target.value); setError(""); }}
          placeholder="Describe the advisory, affected area, and duration…"
        />
        <label>Attach media (optional)</label>
        <div className="media-picker">
          <button
            type="button"
            className={media?.kind === "photo" ? "attached" : ""}
            onClick={() => photoInput.current?.click()}
            disabled={Boolean(uploadingMedia)}
          >
            {uploadingMedia?.target === "new" && uploadingMedia.kind === "image"
              ? <><span className="button-spinner" /> Uploading image…</>
              : <><Camera size={16} /> Add photo</>}
          </button>
          <button
            type="button"
            className={media?.kind === "video" || media?.kind === "gif" ? "attached" : ""}
            onClick={() => videoInput.current?.click()}
            disabled={Boolean(uploadingMedia)}
          >
            {uploadingMedia?.target === "new" && uploadingMedia.kind === "video"
              ? <><span className="button-spinner" /> Uploading video…</>
              : <><Video size={16} /> Add video</>}
          </button>
        </div>
        <input ref={photoInput} hidden type="file" accept="image/*" onChange={(event) => { uploadMedia(event.target.files?.[0], "new"); event.target.value = ""; }} />
        <input ref={videoInput} hidden type="file" accept="video/*,.gif" onChange={(event) => { uploadMedia(event.target.files?.[0], "new"); event.target.value = ""; }} />
        {uploadingMedia?.target === "new" && (
          <div className="advisory-media-upload-status" role="status" aria-live="polite">
            Uploading {uploadingMedia.kind === "video" ? "video" : "image"}: {uploadingMedia.name}
          </div>
        )}
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
        {user?.role !== "barangay_staff" && <>
          <label htmlFor="advisory-audience">Audience</label>
          <select id="advisory-audience" value={audience} onChange={(event) => setAudience(event.target.value)}>
            <option>All barangays</option>
            <option>Brgy. Central</option>
            <option>Brgy. Dawan</option>
            <option>Brgy. Sainz</option>
            <option>Brgy. Matiao</option>
            <option>Brgy. Dahican</option>
          </select>
        </>}
        <div className="advisory-audience-preview" aria-live="polite">
          <MapPin size={17} />
          <div>
            <strong>Audience preview</strong>
            <span>
              {getAdvisoryAudience(user, audience) === "All barangays"
                ? "Residents across all barangays"
                : `Residents in ${getAdvisoryAudience(user, audience)}`}
            </span>
          </div>
        </div>
        <button type="button" className="primary-button" onClick={publish} disabled={isPublishing}>
          <Send size={16} /> {isPublishing ? "Publishing…" : "Publish advisory"}
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
          <div className="advisory-panel-heading">
            <h2>{publishedOnly ? "All published advisories" : "Published advisories"}</h2>
            {!publishedOnly && <p>Recent updates shown in the resident app.</p>}
          </div>
          {publishedOnly ? (
            <span className="muted">{isLoadingAdvisories ? "Loading…" : `${advisories.length} published`}</span>
          ) : (
            <button type="button" className="text-link" onClick={onViewAll}>View all <span aria-hidden="true">→</span></button>
          )}
        </div>
        {publishedOnly && canManageNewsCarousel && (
          <section className="news-carousel-manager" aria-labelledby="news-carousel-manager-title">
            <div className="news-carousel-manager-heading">
              <div>
                <span className="news-carousel-manager-icon" aria-hidden="true"><Image size={19} /></span>
                <div>
                  <h3 id="news-carousel-manager-title">Resident News carousel</h3>
                  <p>Select photo or GIF advisories to highlight in the resident app.</p>
                </div>
              </div>
              <strong className={featuredCount >= 5 ? "news-carousel-limit reached" : "news-carousel-limit"}>
                {featuredCount} <span>/ 5</span>
              </strong>
            </div>
            <div className="news-carousel-slot-track" aria-label={`${featuredCount} of 5 carousel slots used`}>
              {Array.from({ length: 5 }, (_, index) => (
                <span className={index < featuredCount ? "filled" : ""} key={index} />
              ))}
            </div>
            <div className="news-carousel-preview">
              <div className="news-carousel-preview-heading">
                <strong>Currently featured</strong>
                <span>{featuredCarouselAdvisories.length} post{featuredCarouselAdvisories.length === 1 ? "" : "s"}</span>
              </div>
              {featuredCarouselAdvisories.length > 0 ? (
                <div className="news-carousel-preview-list">
                  {featuredCarouselAdvisories.map((advisory) => {
                    const mediaUrl = advisory.media?.src || advisory.media_url;
                    const removing = savingCarouselAdvisoryId === advisory.id;
                    return (
                      <article className="news-carousel-preview-item" key={advisory.id}>
                        <img src={mediaUrl} alt="" />
                        <div className="news-carousel-preview-copy">
                          <strong>{advisory.title}</strong>
                          <span>{advisory.type === "alert" ? "Alert" : advisory.type === "announcement" ? "Announcement" : "Advisory"}</span>
                        </div>
                        <button
                          type="button"
                          className="news-carousel-remove-button"
                          aria-label={`Remove ${advisory.title} from the News carousel`}
                          disabled={removing}
                          onClick={() => setPublishedNewsCarousel(advisory, false)}
                        >
                          {removing ? <span className="button-spinner" /> : <Trash2 size={15} />}
                          <span>{removing ? "Removing" : "Remove"}</span>
                        </button>
                      </article>
                    );
                  })}
                </div>
              ) : (
                <div className="news-carousel-preview-empty">
                  <Image size={20} />
                  <span>No advisories are featured in the carousel yet.</span>
                </div>
              )}
            </div>
          </section>
        )}
        <div className={publishedOnly ? "published-advisory-cards" : ""}>
        {isLoadingAdvisories ? (
          <div className="advisory-loading-list" role="status" aria-label="Loading advisories">
            {Array.from({ length: publishedOnly ? 4 : 2 }, (_, index) => (
              <div className="advisory-loading-card" key={index} aria-hidden="true">
                <i className="skeleton-line advisory-skeleton-tag" />
                <i className="skeleton-line advisory-skeleton-title" />
                <i className="skeleton-line" />
                <i className="skeleton-line advisory-skeleton-copy" />
              </div>
            ))}
          </div>
        ) : !displayedAdvisories.length ? (
          error ? (
            <p className="advisory-empty" role="alert">{error}</p>
          ) : (
            <div className="advisory-empty-state" role="status">
              <Megaphone size={24} aria-hidden="true" />
              <span>No published advisories yet.</span>
            </div>
          )
        ) : displayedAdvisories.map((advisory) => {
          const [label, AdvisoryIcon] = typeMeta[advisory.type];
          const mediaKind = advisory.media?.kind || advisory.media_kind;
          const mediaUrl = advisory.media?.src || advisory.media_url;
          const featured = isNewsCarouselFeatured(advisory.featured_in_news);
          const carouselEligible = ["photo", "image", "gif"].includes(String(mediaKind ?? "").toLowerCase()) && Boolean(mediaUrl);
          const carouselAtLimit = featuredCount >= 5 && !featured;
          return (
            <div className={`advisory-card ${advisory.type === "alert" ? "advertisement" : advisory.type}`} key={advisory.id}>
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
              {publishedOnly && canManageNewsCarousel && (
                <div className={`news-carousel-card-setting ${featured ? "selected" : ""}`}>
                  <div className="news-carousel-card-setting-content">
                    <span>
                      <strong>News carousel</strong>
                      <small>{carouselEligible ? (featured ? "Featured on the resident News screen" : "Available to feature") : "Photo or GIF required"}</small>
                    </span>
                    <button
                      type="button"
                      className={`news-carousel-toggle ${featured ? "active" : ""}`}
                      role="switch"
                      aria-checked={featured}
                      aria-label={`${featured ? "Remove" : "Add"} ${advisory.title} ${featured ? "from" : "to"} the News carousel`}
                      disabled={!carouselEligible || carouselAtLimit || savingCarouselAdvisoryId === advisory.id}
                      onClick={() => setPublishedNewsCarousel(advisory, !featured)}
                    >
                      <span aria-hidden="true" />
                    </button>
                  </div>
                </div>
              )}
              <div className="advisory-card-footer">
                <small>{advisory.created_at ? new Date(advisory.created_at).toLocaleString() : "Recently issued"}</small>
                <div className="advisory-engagement-summary">
                  <span>
                    <Heart size={13} aria-hidden="true" />
                    {Number(advisory.reaction_count) || 0}
                  </span>
                  <span>
                    <MessageCircle size={13} aria-hidden="true" />
                    {Number(advisory.comment_count) || 0}
                  </span>
                  <button
                    type="button"
                    className="advisory-engagement-trigger"
                    onClick={() => onViewEngagement?.(advisory)}
                  >
                    View activity
                  </button>
                </div>
                <span>
                  <button
                    type="button"
                    aria-label={`Edit advisory: ${advisory.title}`}
                    title="Edit advisory"
                    onClick={() => openEdit(advisory)}
                  >
                    <Pencil size={14} />
                  </button>
                  <button
                    type="button"
                    aria-label={archivingAdvisoryId === advisory.id ? "Archiving advisory" : `Archive advisory: ${advisory.title}`}
                    title={archivingAdvisoryId === advisory.id ? "Archiving…" : "Archive advisory"}
                    disabled={archivingAdvisoryId !== null}
                    onClick={() => deleteAdvisory(advisory.id)}
                  >
                    {archivingAdvisoryId === advisory.id ? <span className="button-spinner" /> : <Trash2 size={14} />}
                  </button>
                </span>
              </div>
            </div>
          );
        })}
        </div>
        {publishedOnly && !isLoadingAdvisories && advisories.length > 0 && (
          <div className="advisory-pagination">
            <span>
              Showing {firstVisibleAdvisory}–{lastVisibleAdvisory} of{" "}
              {advisories.length} advisories
            </span>
            {totalAdvisoryPages > 1 && (
              <nav className="advisory-pagination-controls" aria-label="Published advisory pages">
                <button
                  type="button"
                  aria-label="Previous page"
                  disabled={currentAdvisoryPage === 1}
                  onClick={() => setAdvisoryPage(currentAdvisoryPage - 1)}
                >
                  <ChevronLeft size={15} aria-hidden="true" />
                </button>
                <span aria-live="polite">
                  Page {currentAdvisoryPage} of {totalAdvisoryPages}
                </span>
                <button
                  type="button"
                  aria-label="Next page"
                  disabled={currentAdvisoryPage === totalAdvisoryPages}
                  onClick={() => setAdvisoryPage(currentAdvisoryPage + 1)}
                >
                  <ChevronRight size={15} aria-hidden="true" />
                </button>
              </nav>
            )}
          </div>
        )}
      </article>

      {editingAdvisory && createPortal(
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
              <button type="button" className={editingAdvisory.draftType === "advertisement" ? "selected advertisement" : "advertisement"} onClick={() => setEditingAdvisory((current) => ({ ...current, draftType: "advertisement" }))}>
                <Image size={16} strokeWidth={2.2} /> Advertisement
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
                disabled={Boolean(uploadingMedia)}
              >
                {uploadingMedia?.target === "edit" && uploadingMedia.kind === "image"
                  ? <><span className="button-spinner" /> Uploading image…</>
                  : <><Camera size={16} /> Add photo</>}
              </button>
              <button
                type="button"
                className={editingAdvisory.draftMedia?.kind === "gif" || editingAdvisory.draftMedia?.kind === "video" ? "attached" : ""}
                onClick={() => editVideoInput.current?.click()}
                disabled={Boolean(uploadingMedia)}
              >
                {uploadingMedia?.target === "edit" && uploadingMedia.kind === "video"
                  ? <><span className="button-spinner" /> Uploading video…</>
                  : <><Video size={16} /> Add video</>}
              </button>
            </div>

            <input ref={editPhotoInput} hidden type="file" accept="image/*" onChange={(event) => { uploadMedia(event.target.files?.[0], "edit"); event.target.value = ""; }} />
            <input ref={editVideoInput} hidden type="file" accept="video/*,.gif" onChange={(event) => { uploadMedia(event.target.files?.[0], "edit"); event.target.value = ""; }} />
            {uploadingMedia?.target === "edit" && (
              <div className="advisory-media-upload-status" role="status" aria-live="polite">
                Uploading {uploadingMedia.kind === "video" ? "video" : "image"}: {uploadingMedia.name}
              </div>
            )}

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
            {error && <div className="login-error" role="alert">{error}</div>}

            <div className="advisory-edit-actions">
              <button
                type="button"
                className="secondary-button danger-button"
                onClick={() => deleteAdvisory(editingAdvisory.id)}
                disabled={archivingAdvisoryId !== null}
              >
                {archivingAdvisoryId === editingAdvisory.id ? <span className="button-spinner" /> : <Trash2 size={16} />}
                {archivingAdvisoryId === editingAdvisory.id ? "Archiving…" : "Archive"}
              </button>
              <button type="button" className="primary-button" onClick={saveEdit}>
                <CheckCircle2 size={16} /> Save changes
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
}
