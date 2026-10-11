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

export function getReportScope(user, tableAlias = "r") {
  if (user?.role !== "barangay_staff") {
    return { sql: "", params: [], allows: () => true };
  }

  return {
    sql: ` AND ${tableAlias}.location = ?`,
    params: [user.barangay],
    allows: (report) =>
      Boolean(user.barangay) && report?.location === user.barangay,
  };
}
