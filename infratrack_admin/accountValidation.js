export function normalizeMobileNumber(value) {
  if (typeof value !== "string" || !/^[+\d\s()-]+$/.test(value.trim())) {
    return null;
  }

  const digits = value.replace(/\D/g, "");
  return /^\d{11}$/.test(digits) ? digits : null;
}

export async function findDuplicateAccount(connection, { name, email, mobile, excludeId }) {
  const conditions = [
    "LOWER(TRIM(name)) = LOWER(?)",
    "LOWER(TRIM(email)) = LOWER(?)",
    "REGEXP_REPLACE(COALESCE(mobile, ''), '[^0-9]', '') = ?",
  ];
  const params = [name.trim(), email.trim().toLowerCase(), mobile];

  let query = `SELECT id FROM users WHERE (${conditions.join(" OR ")})`;
  if (excludeId !== undefined && excludeId !== null) {
    query += " AND id <> ?";
    params.push(excludeId);
  }
  query += " LIMIT 1";

  const [rows] = await connection.query(query, params);
  return rows[0] ?? null;
}
