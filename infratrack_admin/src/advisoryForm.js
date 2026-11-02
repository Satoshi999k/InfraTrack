export const MAX_NEWS_CAROUSEL_ITEMS = 5;

export function isNewsCarouselOnlyUpdate(body = {}) {
  const keys = Object.keys(body ?? {});
  return keys.length === 1 && Object.hasOwn(body, "featuredInNews");
}


export function isNewsCarouselFeatured(value) {
  return value === true || value === 1 || value === "1";
}

export function getFeaturedNewsCarouselAdvisories(advisories) {
  return advisories.filter((advisory) => {
    const media = advisory.media;
    const mediaKind = media?.kind || advisory.media_kind;
    const mediaUrl = media?.src || advisory.media_url;
    const kind = String(mediaKind ?? "").toLowerCase();

    return (
      isNewsCarouselFeatured(advisory.featured_in_news) &&
      ["photo", "image", "gif"].includes(kind) &&
      Boolean(mediaUrl)
    );
  });
}

export function applyNewsCarouselSelection(advisories, advisoryId, featuredInNews) {
  return advisories.map((advisory) =>
    advisory.id === advisoryId
      ? { ...advisory, featured_in_news: featuredInNews }
      : advisory,
  );
}

export function getNewsCarouselFeaturedCount(advisories = []) {
  return advisories.filter((advisory) =>
    isNewsCarouselFeatured(advisory.featured_in_news),
  ).length;
}

export function isNewsCarouselMedia(mediaKind, mediaUrl) {
  const kind = String(mediaKind ?? "").trim().toLowerCase();
  return Boolean(mediaUrl) && ["photo", "image", "gif"].includes(kind);
}

export function validateAdvisoryDraft(title, message) {
  if (!title.trim()) return "Enter an advisory title.";
  if (!message.trim()) return "Enter an advisory message.";
  return null;
}

export function validateNewsCarouselFeature({
  featuredInNews,
  featuredCount,
  alreadyFeatured = false,
  mediaKind,
  mediaUrl,
}) {
  if (!featuredInNews) return null;
  if (!isNewsCarouselMedia(mediaKind, mediaUrl)) {
    return "Attach a photo or GIF to feature this advisory in the News carousel.";
  }
  if (!alreadyFeatured && Number(featuredCount) >= MAX_NEWS_CAROUSEL_ITEMS) {
    return "Only five advisories can appear in the News carousel.";
  }
  return null;
}

export function getAdvisoryAudience(user, selectedAudience) {
  if (user?.role === "barangay_staff") {
    return user.barangay || "your assigned barangay";
  }
  return selectedAudience;
}
