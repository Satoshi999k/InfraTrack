export function normalizeIssueText(value = "") {
  return String(value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function tokenizeIssue(value = "") {
  return normalizeIssueText(value)
    .split(" ")
    .filter((token) => token.length > 1);
}

export function computeTokenSimilarity(left = "", right = "") {
  const leftWords = new Set(tokenizeIssue(left));
  const rightWords = new Set(tokenizeIssue(right));
  if (!leftWords.size && !rightWords.size) return 1;
  if (!leftWords.size || !rightWords.size) return 0;
  const overlap = [...leftWords].filter((word) => rightWords.has(word)).length;
  const union = new Set([...leftWords, ...rightWords]).size;
  return union ? overlap / union : 0;
}

export function geoDistanceKm(aLat, aLng, bLat, bLng) {
  if (![aLat, aLng, bLat, bLng].every((value) => Number.isFinite(Number(value)))) return null;
  const toRad = (value) => (Number(value) * Math.PI) / 180;
  const earthRadiusKm = 6371;
  const deltaLat = toRad(Number(bLat) - Number(aLat));
  const deltaLng = toRad(Number(bLng) - Number(aLng));
  const latA = toRad(Number(aLat));
  const latB = toRad(Number(bLat));
  const haversine =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(latA) * Math.cos(latB) * Math.sin(deltaLng / 2) * Math.sin(deltaLng / 2);
  const distance = 2 * earthRadiusKm * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
  return Number(distance);
}

export function computeDuplicateMatch(current = {}, existing = {}) {
  if (!current || !existing) return false;
  const sameCategory = (current.category || "").toLowerCase() === (existing.category || "").toLowerCase();
  if (!sameCategory) return false;

  const currentLocation = normalizeIssueText(current.location || "");
  const existingLocation = normalizeIssueText(existing.location || "");
  const sameLocation = currentLocation && existingLocation && currentLocation === existingLocation;

  const titleScore = computeTokenSimilarity(current.title || "", existing.title || "");
  const normalizedCurrentTitle = normalizeIssueText(current.title || "");
  const normalizedExistingTitle = normalizeIssueText(existing.title || "");
  const titleIncludesExisting = normalizedCurrentTitle.includes(normalizedExistingTitle) || normalizedExistingTitle.includes(normalizedCurrentTitle);

  const distanceKm = geoDistanceKm(current.latitude, current.longitude, existing.latitude, existing.longitude);
  const geoMatch = Number.isFinite(distanceKm) && distanceKm <= 0.12;

  return sameLocation || titleIncludesExisting || titleScore >= 0.35 || geoMatch;
}

export function escalateIssueSeverity(currentSeverity = "", ageHours = 0) {
  const severity = String(currentSeverity || "").trim();
  if (severity === "Resolved" || severity === "Rejected" || severity === "Archived") return severity;
  if (severity === "Low" && ageHours >= 96) return "Medium";
  if (severity === "Medium" && ageHours >= 72) return "High";
  if (severity === "High" && ageHours >= 48) return "Critical";
  return severity;
}

export function getIssuePriorityLabel(issue = {}) {
  const severity = String(issue.severity || "");
  if (issue.duplicate_of) return "Duplicate";
  if (issue.escalated_at) return "Escalated";
  if (severity === "Critical") return "Critical";
  return "Normal";
}
