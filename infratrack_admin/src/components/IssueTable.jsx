import { ChevronRight, Users } from "lucide-react";

export default function IssueTable({ issues, onOpenIssue }) {
  return (
    <div className="card table-card queue-issue-table">
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Issue</th>
              <th>Severity</th>
              <th className="queue-status-heading">Status</th>
              <th>Reported by</th>
              <th>Filed</th>
              <th>Assigned team</th>
              <th aria-hidden="true" />
            </tr>
          </thead>
          <tbody>
            {issues.map((issue) => {
              const automationFlags = [];
              if (issue.same_reporter_duplicate)
                automationFlags.push("Duplicate");
              if (issue.escalated_at) automationFlags.push("Escalated");
              const createdAt = issue.created_at
                ? new Date(issue.created_at)
                : null;
              const filedDate =
                createdAt && !Number.isNaN(createdAt.getTime())
                  ? createdAt.toLocaleDateString()
                  : "Not provided";
              const assignedTeam = issue.assigned_team || issue.assignedTeam;

              return (
                <tr key={issue.id} onClick={() => onOpenIssue?.(issue)}>
                  <td>
                    <div className="issue-title">
                      {issue.media_url ? (
                        <img
                          className="issue-thumb"
                          src={issue.media_url}
                          alt=""
                          loading="lazy"
                        />
                      ) : (
                        <span
                          className={`issue-thumb ${(issue.category || "").toLowerCase()}`}
                          aria-hidden="true"
                        />
                      )}
                      <span>
                        <button
                          type="button"
                          className="issue-row-open"
                          aria-label={`Open report: ${issue.title}`}
                          onClick={(event) => {
                            event.stopPropagation();
                            onOpenIssue?.(issue);
                          }}
                        >
                          {issue.title}
                        </button>
                        <small>
                          #{issue.public_id || issue.id} · {issue.location}
                        </small>
                        {!!automationFlags.length && (
                          <small className="queue-automation-flags">
                            {automationFlags.map((flag) => (
                              <span
                                key={flag}
                                className={`status ${flag === "Escalated" ? "critical" : "medium"}`}
                              >
                                {flag}
                              </span>
                            ))}
                          </small>
                        )}
                      </span>
                    </div>
                  </td>
                  <td data-label="Severity">
                    <span
                      className={`status ${(issue.severity || "").toLowerCase()}`}
                    >
                      {issue.severity || "Not set"}
                    </span>
                  </td>
                  <td data-label="Status">
                    <div className="queue-status">
                      <span
                        className={`status ${(issue.status || "").toLowerCase().replace(" ", "-")}`}
                      >
                        {issue.status || "Unknown"}
                      </span>
                      {issue.status === "In progress" && (
                        <div
                          className="queue-progress"
                          aria-label={`${Number(issue.progress_percentage) || 0}% complete`}
                        >
                          <div className="progress-track">
                            <span
                              style={{
                                width: `${Math.min(100, Math.max(0, Number(issue.progress_percentage) || 0))}%`,
                              }}
                            />
                          </div>
                          <small>
                            {Number(issue.progress_percentage) || 0}% complete
                          </small>
                        </div>
                      )}
                    </div>
                  </td>
                  <td data-label="Reported by">
                    {issue.reporter || "Not provided"}
                  </td>
                  <td data-label="Filed">{filedDate}</td>
                  <td data-label="Assigned team">
                    {assignedTeam ? (
                      <span className="assignee">
                        <i className="assignee-avatar teal">
                          <Users size={13} />
                        </i>
                        {assignedTeam}
                      </span>
                    ) : (
                      <span className="unassigned">
                        <i className="assignee-avatar empty">
                          <Users size={14} />
                        </i>
                        Not assigned
                      </span>
                    )}
                  </td>
                  <td className="queue-row-chevron" aria-hidden="true">
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
