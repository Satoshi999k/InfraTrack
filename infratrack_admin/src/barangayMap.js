export const barangayMapCenters = {
  central: [6.9612515, 126.2069944],
  "purok 3": [6.9612515, 126.2069944],
  dawan: [6.8993278, 126.15106],
  sainz: [6.9588636, 126.2201871],
  matiao: [6.9450796, 126.2323952],
  dahican: [6.9466732, 126.2603384],
  bobon: [6.8683574, 126.3264295],
};

export function normalizeBarangayName(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/^(?:brgy\.?|barangay)\s*/, "")
    .replace(/\s+/g, " ");
}

export function getBarangayMapCenter(barangay) {
  return barangayMapCenters[normalizeBarangayName(barangay)] ?? null;
}
