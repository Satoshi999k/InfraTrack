export const barangayPolygons = {
  'Brgy. Central': [
    [6.9654, 126.2055],
    [6.9698, 126.2055],
    [6.9701, 126.2147],
    [6.9652, 126.2162],
    [6.9604, 126.2131],
    [6.9588, 126.2089],
    [6.9608, 126.2057],
    [6.9654, 126.2055],
  ],
  'Brgy. Dawan': [
    [6.8948, 126.1458],
    [6.9045, 126.1458],
    [6.9075, 126.1584],
    [6.8999, 126.1635],
    [6.8926, 126.1587],
    [6.8928, 126.1504],
    [6.8948, 126.1458],
  ],
  'Brgy. Sainz': [
    [6.9522, 126.2178],
    [6.9615, 126.2178],
    [6.9625, 126.2347],
    [6.9536, 126.2384],
    [6.9483, 126.2312],
    [6.9492, 126.2214],
    [6.9522, 126.2178],
  ],
  'Brgy. Matiao': [
    [6.9398, 126.2243],
    [6.9502, 126.2269],
    [6.9524, 126.2389],
    [6.9428, 126.2435],
    [6.9363, 126.2364],
    [6.9369, 126.2282],
    [6.9398, 126.2243],
  ],
  'Brgy. Dahican': [
    [6.9385, 126.2517],
    [6.9488, 126.2508],
    [6.9518, 126.2686],
    [6.9448, 126.2738],
    [6.9364, 126.2688],
    [6.9349, 126.2577],
    [6.9385, 126.2517],
  ],
};

export function isPointInPolygon(lat, lng, polygon) {
  if (!Array.isArray(polygon) || !polygon.length) return false;
  const x = Number(lng);
  const y = Number(lat);
  let inside = false;

  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [latI, lngI] = polygon[i];
    const [latJ, lngJ] = polygon[j];
    const xI = Number(lngI);
    const yI = Number(latI);
    const xJ = Number(lngJ);
    const yJ = Number(latJ);
    const intersect = ((yI > y) !== (yJ > y)) && (x < ((xJ - xI) * (y - yI)) / (yJ - yI || 1) + xI);
    if (intersect) inside = !inside;
  }

  return inside;
}

export function normalizeBarangayName(value = "") {
  const text = String(value ?? "").trim();
  if (!text) return "";
  const withoutPrefix = text.replace(/^brgy\.?\s*/i, "").trim();
  return withoutPrefix.charAt(0).toUpperCase() + withoutPrefix.slice(1).toLowerCase();
}

export function getBarangayForCoordinates(latitude, longitude) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  const match = Object.entries(barangayPolygons).find(([, polygon]) => isPointInPolygon(lat, lng, polygon));
  return match ? match[0] : null;
}

export function validateBarangayCoordinates({ latitude, longitude, location, barangay }) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return { valid: true, matchedBarangay: null, reason: "No coordinates provided" };
  }

  const detectedBarangay = getBarangayForCoordinates(lat, lng);
  if (!detectedBarangay) {
    return { valid: false, matchedBarangay: null, reason: "Coordinates are outside the approved Mati City barangay boundaries." };
  }

  const providedValue = location || barangay || "";
  const providedLabel = normalizeBarangayName(providedValue);
  const explicitBarangay = /brgy|barangay/i.test(String(providedValue));
  if (explicitBarangay && providedLabel && providedLabel !== detectedBarangay.replace(/^Brgy\.\s*/i, "")) {
    return { valid: false, matchedBarangay: detectedBarangay, reason: `Coordinates match ${detectedBarangay}, not ${providedLabel}.` };
  }

  return { valid: true, matchedBarangay: detectedBarangay, reason: "Valid location data" };
}
