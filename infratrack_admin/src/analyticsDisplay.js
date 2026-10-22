export function getAnalyticsCategoryRows(categories, reportTotal) {
  const rows = categories.map((category) => ({
    ...category,
    count: Number(category.count) || 0,
  }));
  const categorizedTotal = rows.reduce(
    (total, category) => total + category.count,
    0,
  );
  const otherCount = Math.max(0, (Number(reportTotal) || 0) - categorizedTotal);

  if (otherCount > 0) {
    rows.push({ name: "Other categories", count: otherCount });
  }

  return rows;
}

export function formatAnalyticsTrendLabel(label, period) {
  const value = String(label ?? "");
  const match =
    period === "day"
      ? value.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):\d{2}$/)
      : period === "year"
        ? value.match(/^(\d{4})-(\d{2})$/)
        : value.match(/^(\d{4})-(\d{2})-(\d{2})$/);

  if (!match) return value;

  const [, year, month, day, hour] = match;
  const date = new Date(
    Number(year),
    Number(month) - 1,
    Number(day) || 1,
    Number(hour) || 0,
  );
  const options =
    period === "day"
      ? { month: "short", day: "numeric", hour: "numeric" }
      : period === "year"
        ? { month: "short", year: "2-digit" }
        : { month: "short", day: "numeric" };

  return new Intl.DateTimeFormat("en", options).format(date);
}
