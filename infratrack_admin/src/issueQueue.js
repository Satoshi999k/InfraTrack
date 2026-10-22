import { normalizeBarangayName } from "./barangayMap.js";
import { issueMatchesBarangay } from "./issueBarangay.js";
import { normalizeReportCategory } from "../reportCategories.js";

function getIssueAgeDays(issue, now) {
  const createdAt = Date.parse(issue.created_at);
  return Number.isFinite(createdAt) ? (now - createdAt) / 86400000 : null;
}

export function getAvailableIssueBarangays(issues) {
  const barangays = new Map();

  for (const issue of issues) {
    const location = normalizeBarangayName(issue.location);
    const isGenericCityLocation =
      !location || location === "mati" || location === "mati city";
    const source = isGenericCityLocation
      ? issue.reporter_barangay
      : issue.location;
    const key = normalizeBarangayName(source);
    if (!key || barangays.has(key)) continue;

    const sourceText = String(source).trim();
    const hadBarangayPrefix =
      isGenericCityLocation || /^(?:brgy\.?|barangay)\s*/i.test(sourceText);
    const label = key
      .split(" ")
      .map((part) => (part ? part[0].toUpperCase() + part.slice(1) : ""))
      .join(" ");
    barangays.set(key, hadBarangayPrefix ? `Brgy. ${label}` : label);
  }

  return [...barangays]
    .map(([value, label]) => ({ value, label }))
    .sort((left, right) => left.label.localeCompare(right.label));
}

export function filterIssueQueue(
  issues,
  { category = "all", barangay = "all", date = "all" } = {},
  now = Date.now(),
) {
  return issues.filter((issue) => {
    const matchesCategory =
      category === "all" ||
      normalizeReportCategory(issue.category) === category;
    const matchesBarangay =
      barangay === "all" || issueMatchesBarangay(issue, barangay);
    const ageDays = getIssueAgeDays(issue, now);
    const matchesDate =
      date === "all" || (ageDays !== null && ageDays <= Number(date));

    return matchesCategory && matchesBarangay && matchesDate;
  });
}

export function countIssueQueueStatuses(issues) {
  return {
    all: issues.length,
    pending: issues.filter((issue) => issue.status === "Reported").length,
    "In progress": issues.filter((issue) => issue.status === "In progress")
      .length,
    Resolved: issues.filter((issue) => issue.status === "Resolved").length,
  };
}

export function paginateIssueQueue(issues, page, pageSize = 10) {
  const totalPages = Math.max(1, Math.ceil(issues.length / pageSize));
  const currentPage = Math.min(Math.max(1, page), totalPages);
  const startIndex = (currentPage - 1) * pageSize;

  return {
    currentPage,
    totalPages,
    startIndex,
    endIndex: Math.min(startIndex + pageSize, issues.length),
    issues: issues.slice(startIndex, startIndex + pageSize),
  };
}
