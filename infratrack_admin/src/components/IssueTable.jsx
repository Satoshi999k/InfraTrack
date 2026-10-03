import { ChevronRight, Users } from "lucide-react";

export default function IssueTable({ issues, onOpenIssue }) {
  return (
    <div className="card table-card">
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Issue</th>
              <th>Severity</th>
              <th>Status</th>
              <th>Reported by</th>
              <th>Filed</th>
              <th>Assigned to</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {issues.map((issue) => {
              const automationFlags = [];
              if (issue.duplicate_of) automationFlags.push("Duplicate");
              if (issue.escalated_at) automationFlags.push("Escalated");

              return (
                <tr
                  key={issue.id}
                  onClick={() => onOpenIssue?.(issue)}
                >
                  <td>
                    <div className="issue-title">
                      <span
                        className={`issue-thumb ${issue.category.toLowerCase()}`}
                      />
                      <span>
                        <b>{issue.title}</b>
                        <small>
                          #{issue.public_id || issue.id} · {issue.location}
                        </small>
                        {!!automationFlags.length && (
                          <small style={{ display: "flex", gap: 6, marginTop: 4 }}>
                            {automationFlags.map((flag) => (
                              <span key={flag} className={`status ${flag === "Escalated" ? "critical" : "medium"}`} style={{ padding: "2px 8px", fontSize: 10, lineHeight: 1.2, textTransform: "uppercase" }}>
                                {flag}
                              </span>
                            ))}
                          </small>
                        )}
                      </span>
                    </div>
                  </td>
                <td>
                  <span className={`status ${issue.severity.toLowerCase()}`}>
                    {issue.severity}
                  </span>
                </td>
                <td>
                  <span
                    className={`status ${issue.status.toLowerCase().replace(" ", "-")}`}
                  >
                    {issue.status}
                  </span>
                </td>
                <td>{issue.reporter}</td>
                <td>
                  {issue.created_at
                    ? new Date(issue.created_at).toLocaleDateString()
                    : "—"}
                </td>
                  <td>
                    {issue.status === "Resolved" ? (
                      <span className="assignee">
                        <i className={`assignee-avatar ${issue.id === "MT-2026-860" ? "purple" : "clay"}`}>
                          {issue.id === "MT-2026-860" ? "TD" : "TA"}
                        </i>
                        {issue.id === "MT-2026-860" ? "Team Delta" : "Team Alpha"}
                      </span>
                    ) : issue.id === "MT-2026-879" ? (
                      <span className="assignee">
                        <i className="assignee-avatar teal">MW</i>Mati Water District
                      </span>
                    ) : (
                      <span className="unassigned">
                        <i className="assignee-avatar empty"><Users size={14} /></i>
                        Unassigned
                        <button className="assign-button" onClick={(event) => event.stopPropagation()}>Assign</button>
                      </span>
                    )}
                  </td>
                  <td>
                    <ChevronRight size={17} />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
