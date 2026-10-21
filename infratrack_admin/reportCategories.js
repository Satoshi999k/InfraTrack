export const REPORT_CATEGORIES = Object.freeze([
  "Roads",
  "Public Buildings",
  "Streetlights",
  "Electric Poles",
  "Drainage",
]);

const categoryAliases = new Map([
  ["road", "Roads"],
  ["roads", "Roads"],
  ["public building", "Public Buildings"],
  ["public buildings", "Public Buildings"],
  ["lighting", "Streetlights"],
  ["streetlight", "Streetlights"],
  ["streetlights", "Streetlights"],
  ["electric pole", "Electric Poles"],
  ["electric poles", "Electric Poles"],
  ["drainage", "Drainage"],
]);

export function normalizeReportCategory(category) {
  if (typeof category !== "string") return null;
  return categoryAliases.get(category.trim().toLowerCase()) ?? null;
}

export function aggregateReportCategories(rows) {
  const counts = new Map();
  for (const row of rows) {
    const category = normalizeReportCategory(row.name);
    if (!category) continue;
    counts.set(category, (counts.get(category) || 0) + Number(row.count || 0));
  }
  return [...counts]
    .map(([name, count]) => ({ name, count }))
    .sort((left, right) => right.count - left.count || left.name.localeCompare(right.name));
}
