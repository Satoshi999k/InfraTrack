export const MAX_NEWS_CAROUSEL_ITEMS = 5;

export function isNewsCarouselFeatured(value) {
  return value === true || value === 1 || value === "1";
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
