export function getAdvisoryScope(user, tableAlias = "advisories") {
  if (user?.role !== "barangay_staff") {
    return { sql: "", params: [], allows: () => true };
  }

  return {
    sql: ` AND ${tableAlias}.barangay = ?`,
    params: [user.barangay],
    allows: (advisory) => advisory?.barangay === user.barangay,
  };
}

export function getAdvisoryReadScope(user, tableAlias = "a") {
  if (user?.role !== "barangay_staff") {
    return { sql: "", params: [], allows: () => true };
  }

  return {
    sql: ` AND (${tableAlias}.barangay = ? OR ${tableAlias}.audience = 'All barangays')`,
    params: [user.barangay],
    allows: (advisory) =>
      advisory?.barangay === user.barangay ||
      advisory?.audience === "All barangays",
  };
}

export function normalizeBarangayName(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/^(?:brgy\.?|barangay)\s*/, "")
    .replace(/\s+/g, " ");
}

function normalizedBarangaySql(value) {
  return `TRIM(REPLACE(REPLACE(REPLACE(LOWER(TRIM(${value})), 'barangay ', ''), 'brgy. ', ''), 'brgy ', ''))`;
}

function isGenericCityLocation(value) {
  const location = String(value ?? "").trim().toLowerCase();
  return location === "" || location === "mati" || location === "mati city";
}

export function reportMatchesBarangay(report, barangay) {
  if (!normalizeBarangayName(barangay)) return false;
  const location = normalizeBarangayName(report?.location);
  const reportBarangay = isGenericCityLocation(report?.location)
    ? report?.reporter_barangay
    : location;
  return normalizeBarangayName(reportBarangay) === normalizeBarangayName(barangay);
}

export function getResidentScope(user, column = "u.barangay") {
  if (user?.role !== "barangay_staff") {
    return { sql: "", params: [], allows: () => true };
  }

  return {
    sql: ` AND ${normalizedBarangaySql(column)} = ${normalizedBarangaySql("?")}`,
    params: [user.barangay],
    allows: (resident) =>
      Boolean(normalizeBarangayName(user.barangay)) &&
      normalizeBarangayName(resident?.barangay) ===
        normalizeBarangayName(user.barangay),
  };
}

export function getReportScope(user, tableAlias = "r") {
  if (user?.role !== "barangay_staff") {
    return { sql: "", params: [], allows: () => true };
  }

  return {
    sql: ` AND (
      ${normalizedBarangaySql(`${tableAlias}.location`)} = ${normalizedBarangaySql("?")}
      OR (
        LOWER(TRIM(${tableAlias}.location)) IN ('', 'mati', 'mati city')
        AND EXISTS (
          SELECT 1 FROM users report_owner
          WHERE report_owner.id = ${tableAlias}.reporter_id
            AND ${normalizedBarangaySql("report_owner.barangay")} = ${normalizedBarangaySql("?")}
        )
      )
    )`,
    params: [user.barangay, user.barangay],
    allows: (report) => reportMatchesBarangay(report, user.barangay),
  };
}
