import { useMemo, useState } from "react";
import IssueTable from "../components/IssueTable";

export default function IssueQueuePage({ issues, onOpenIssue }) {
  const [statusFilter, setStatusFilter] = useState("all");
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [barangayFilter, setBarangayFilter] = useState("all");
  const [dateFilter, setDateFilter] = useState("all");
  const countByStatus = (status) =>
    issues.filter((issue) => issue.status === status).length;
  const filteredIssues = useMemo(
    () => issues.filter((issue) => {
      const matchesStatus = statusFilter === "all"
        || (statusFilter === "pending" ? issue.status === "Reported" : issue.status === statusFilter);
      const matchesCategory = categoryFilter === "all" || issue.category === categoryFilter;
      const matchesBarangay = barangayFilter === "all" || issue.location === barangayFilter;
      const age = issue.created_at ? (Date.now() - new Date(issue.created_at).getTime()) / 86400000 : 0;
      const matchesDate = dateFilter === "all" || (dateFilter === "7" ? age <= 7 : age <= 30);
      return matchesStatus && matchesCategory && matchesBarangay && matchesDate;
    }),
    [issues, statusFilter, categoryFilter, barangayFilter, dateFilter],
  );

  return (
    <div className="card queue-card">
      <div className="queue-toolbar">
        <div className="filters queue-filters">
          <button className={`filter ${statusFilter === "all" ? "active" : ""}`} onClick={() => setStatusFilter("all")}>All ({issues.length})</button>
          <button className={`filter ${statusFilter === "pending" ? "active" : ""}`} onClick={() => setStatusFilter("pending")}>Pending ({countByStatus("Reported")})</button>
          <button className={`filter ${statusFilter === "In progress" ? "active" : ""}`} onClick={() => setStatusFilter("In progress")}>In progress ({countByStatus("In progress")})</button>
          <button className={`filter ${statusFilter === "Resolved" ? "active" : ""}`} onClick={() => setStatusFilter("Resolved")}>Resolved ({countByStatus("Resolved")})</button>
        </div>
        <div className="queue-selects">
          <select aria-label="Filter by category" value={categoryFilter} onChange={(event) => setCategoryFilter(event.target.value)}>
            <option value="all">All categories</option>
            <option>Roads</option>
            <option>Water</option>
            <option>Drainage</option>
            <option>Lighting</option>
          </select>
          <select aria-label="Filter by barangay" value={barangayFilter} onChange={(event) => setBarangayFilter(event.target.value)}>
            <option value="all">All barangays</option>
            <option>Brgy. Central</option>
            <option>Brgy. Dawan</option>
            <option>Brgy. Sainz</option>
            <option>Brgy. Matiao</option>
            <option>Brgy. Dahican</option>
          </select>
          <select aria-label="Filter by date" value={dateFilter} onChange={(event) => setDateFilter(event.target.value)}>
            <option value="all">All dates</option><option value="7">Last 7 days</option><option value="30">Last 30 days</option>
          </select>
          <button type="button" className="secondary-button" onClick={() => window.print()}>Print report</button>
        </div>
      </div>
      <IssueTable issues={filteredIssues} onOpenIssue={onOpenIssue} />
      <div className="queue-footer">
        <span>
          {filteredIssues.length === 0
            ? "No reports found"
            : `Showing 1–${filteredIssues.length} of ${filteredIssues.length} reports`}
        </span>
        <div className="pagination">
          <button aria-label="Previous page" disabled>‹</button>
          <button className="active">1</button>
          <button aria-label="Next page" disabled>›</button>
        </div>
      </div>
    </div>
  );
}
