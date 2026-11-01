import { normalizeBarangayName } from "./barangayMap.js";

export function issueMatchesBarangay(issue, barangay) {
  const location = normalizeBarangayName(issue?.location);
  const selectedBarangay = normalizeBarangayName(barangay);
  const hasCoordinates =
    issue?.latitude != null &&
    issue?.latitude !== "" &&
    issue?.longitude != null &&
    issue?.longitude !== "";
  const reportBarangay =
    (location === "mati city" || location === "mati" || !location) &&
    !hasCoordinates
      ? normalizeBarangayName(issue?.reporter_barangay)
      : location;

  return reportBarangay !== "" && reportBarangay === selectedBarangay;
}
