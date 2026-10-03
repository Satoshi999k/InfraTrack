export function buildLocalIssueMatches(issues, term) {
  const normalized = term.trim();
  if (!normalized) return [];

  const lower = normalized.toLowerCase();
  return issues
    .filter((issue) => `${issue.title} ${issue.location} ${issue.public_id ?? ""}`.toLowerCase().includes(lower))
    .map((issue) => ({
      display_name: `Issue report: ${issue.title} · ${issue.location}`,
      lat: issue.latitude,
      lon: issue.longitude,
      issue,
    }));
}

export async function searchAddressLocations(term, issues, { fetchImpl = fetch, timeoutMs = 6000 } = {}) {
  const normalized = term.trim();
  if (!normalized) return [];

  const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=5&countrycodes=ph&bounded=1&viewbox=126.15,6.85,126.35,7.05&q=${encodeURIComponent(`${normalized}, Mati City, Davao Oriental, Philippines`)}`;

  let timeout = null;

  try {
    const controller = typeof AbortController !== "undefined" ? new AbortController() : null;
    timeout = controller ? setTimeout(() => controller.abort(), timeoutMs) : null;
    const response = await fetchImpl(url, {
      headers: {
        Accept: "application/json",
        "Accept-Language": "en",
      },
      signal: controller?.signal,
    });

    if (!response.ok) {
      throw new Error(`Geocoder request failed with status ${response.status}`);
    }

    const data = await response.json();
    if (Array.isArray(data) && data.length) {
      return data;
    }
  } catch (error) {
    const fallback = buildLocalIssueMatches(issues, normalized);
    if (fallback.length) {
      return fallback;
    }
    return [];
  } finally {
    if (timeout) clearTimeout(timeout);
  }

  return buildLocalIssueMatches(issues, normalized);
}
