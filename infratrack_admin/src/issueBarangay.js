import { normalizeBarangayName } from "./barangayMap.js";

export function issueMatchesBarangay(issue, barangay) {
  const location = normalizeBarangayName(issue?.location);
  const selectedBarangay = normalizeBarangayName(barangay);
  const reportBarangay =
    location === "mati city" || location === "mati" || !location
      ? normalizeBarangayName(issue?.reporter_barangay)
      : location;

  return reportBarangay !== "" && reportBarangay === selectedBarangay;
}
