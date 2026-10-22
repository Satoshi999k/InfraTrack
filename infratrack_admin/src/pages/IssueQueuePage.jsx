import { useMemo, useState } from "react";
import { CircleCheck, Clock3, List, LoaderCircle } from "lucide-react";
import IssueTable from "../components/IssueTable";
import { REPORT_CATEGORIES } from "../../reportCategories.js";
import {
  countIssueQueueStatuses,
  filterIssueQueue,
  getAvailableIssueBarangays,
  paginateIssueQueue,
} from "../issueQueue.js";

const PAGE_SIZE = 10;

export default function IssueQueuePage({ issues, onOpenIssue }) {
  const [statusFilter, setStatusFilter] = useState("all");
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [barangayFilter, setBarangayFilter] = useState("all");
  const [dateFilter, setDateFilter] = useState("all");
  const [page, setPage] = useState(1);
  const availableBarangays = useMemo(
    () => getAvailableIssueBarangays(issues),
    [issues],
  );
  const nonStatusFilteredIssues = useMemo(
    () =>
      filterIssueQueue(issues, {
        category: categoryFilter,
        barangay: barangayFilter,
        date: dateFilter,
      }),
    [issues, categoryFilter, barangayFilter, dateFilter],
  );
  const statusCounts = useMemo(
    () => countIssueQueueStatuses(nonStatusFilteredIssues),
    [nonStatusFilteredIssues],
  );
  const filteredIssues = useMemo(
    () =>
      statusFilter === "all"
        ? nonStatusFilteredIssues
        : nonStatusFilteredIssues.filter((issue) =>
            statusFilter === "pending"
              ? issue.status === "Reported"
              : issue.status === statusFilter,
          ),
    [nonStatusFilteredIssues, statusFilter],
  );
  const pagination = useMemo(
    () => paginateIssueQueue(filteredIssues, page, PAGE_SIZE),
    [filteredIssues, page],
  );
  const hasActiveFilters =
    statusFilter !== "all" ||
    categoryFilter !== "all" ||
    barangayFilter !== "all" ||
    dateFilter !== "all";
  const statusOptions = [
    { value: "all", label: "All", Icon: List },
    { value: "pending", label: "Pending", Icon: Clock3 },
    { value: "In progress", label: "In progress", Icon: LoaderCircle },
    { value: "Resolved", label: "Resolved", Icon: CircleCheck },
  ];
  const firstVisibleReport = filteredIssues.length
    ? pagination.startIndex + 1
    : 0;

  function updateFilter(setFilter, value) {
    setFilter(value);
    setPage(1);
  }

  function resetFilters() {
    setStatusFilter("all");
    setCategoryFilter("all");
    setBarangayFilter("all");
    setDateFilter("all");
    setPage(1);
  }

  return (
    <div className="card queue-card">
      <div className="queue-toolbar">
        <div
          className="filters queue-filters"
          role="group"
          aria-label="Filter reports by status"
        >
          {statusOptions.map(({ value, label, Icon }) => (
            <button
              key={value}
              type="button"
              className={`filter ${statusFilter === value ? "active" : ""}`}
              aria-pressed={statusFilter === value}
              onClick={() => updateFilter(setStatusFilter, value)}
            >
              <Icon
                className="queue-filter-icon"
                size={13}
                aria-hidden="true"
              />
              {label} ({statusCounts[value]})
            </button>
          ))}
        </div>
        <div className="queue-selects">
          <select
            aria-label="Filter by category"
            value={categoryFilter}
            onChange={(event) =>
              updateFilter(setCategoryFilter, event.target.value)
            }
          >
            <option value="all">All categories</option>
            {REPORT_CATEGORIES.map((category) => (
              <option key={category}>{category}</option>
            ))}
          </select>
          <select
            aria-label="Filter by barangay"
            value={barangayFilter}
            onChange={(event) =>
              updateFilter(setBarangayFilter, event.target.value)
            }
          >
            <option value="all">All barangays</option>
            {availableBarangays.map(({ value, label }) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
          <select
            aria-label="Filter by date"
            value={dateFilter}
            onChange={(event) =>
              updateFilter(setDateFilter, event.target.value)
            }
          >
            <option value="all">All dates</option>
            <option value="7">Last 7 days</option>
            <option value="30">Last 30 days</option>
          </select>
          {hasActiveFilters && (
            <button
              type="button"
              className="queue-reset-button"
              onClick={resetFilters}
            >
              Clear filters
            </button>
          )}
          <button
            type="button"
            className="secondary-button"
            onClick={() => window.print()}
          >
            Print report
          </button>
        </div>
      </div>
      <div className="queue-screen-results">
        {pagination.issues.length ? (
          <IssueTable issues={pagination.issues} onOpenIssue={onOpenIssue} />
        ) : (
          <div className="queue-empty" role="status">
            <strong>No reports match these filters</strong>
            <span>
              Try changing or clearing the filters to see more reports.
            </span>
          </div>
        )}
      </div>
      {!!filteredIssues.length && (
        <div className="queue-print-results" aria-hidden="true">
          <IssueTable issues={filteredIssues} />
        </div>
      )}
      <div className="queue-footer">
        <span>
          {filteredIssues.length
            ? `Showing ${firstVisibleReport}–${pagination.endIndex} of ${filteredIssues.length} reports`
            : "Showing 0 reports"}
        </span>
        {!!filteredIssues.length && (
          <nav className="pagination" aria-label="Report pages">
            <button
              type="button"
              aria-label="Previous page"
              disabled={pagination.currentPage === 1}
              onClick={() => setPage(pagination.currentPage - 1)}
            >
              ‹
            </button>
            <span aria-live="polite">
              Page {pagination.currentPage} of {pagination.totalPages}
            </span>
            <button
              type="button"
              aria-label="Next page"
              disabled={pagination.currentPage === pagination.totalPages}
              onClick={() => setPage(pagination.currentPage + 1)}
            >
              ›
            </button>
          </nav>
        )}
      </div>
    </div>
  );
}
