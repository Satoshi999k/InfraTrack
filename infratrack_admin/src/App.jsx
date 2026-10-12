import { useEffect, useMemo, useRef, useState } from "react";
import "leaflet/dist/leaflet.css";
import {
  Activity,
  AlertTriangle,
  BarChart3,
  Bell,
  Building2,
  CheckCircle2,
  ChevronRight,
  ClipboardList,
  FileText,
  Flag,
  HelpCircle,
  LayoutDashboard,
  LogOut,
  Map,
  Menu,
  Megaphone,
  Search,
  Settings,
  Star,
  ScrollText,
  Users,
  Wrench,
} from "lucide-react";

import { Modal } from "./components/Modals";
import IssueTable from "./components/IssueTable";
import IssueQueuePage from "./pages/IssueQueuePage";
import MapPage, { LeafletInfrastructureMap } from "./pages/MapPage";
import UsersPage from "./pages/UsersPage";
import AdvisoryPage from "./pages/AdvisoryPage";
import SettingsPage from "./pages/SettingsPage";
import Login from "./Login";
import { API_BASE, apiFetch } from "./api";
import { clearAuthSession, getStoredAuthSession } from "./authSession";
import { canAccessAdminPage, getNavigationGroups } from "./roleNavigation";
import { startVisiblePolling } from "./visiblePolling";

const navIcons = {
  overview: LayoutDashboard,
  queue: ClipboardList,
  map: Map,
  analytics: BarChart3,
  users: Users,
  announce: Megaphone,
  published: FileText,
  logs: ScrollText,
};

function Icon({ icon: IconComponent, size = 18 }) {
  return (
    <IconComponent
      size={size}
      strokeWidth={IconComponent === Megaphone ? 2.4 : 2}
    />
  );
}

export default function App() {
  const [currentUser, setCurrentUser] = useState(() => {
    const { user } = getStoredAuthSession();
    return user;
  });

  const handleLogin = (user) => {
    setCurrentUser(user);
  };

  const handleLogout = () => {
    apiFetch("/auth/logout", { method: "POST" }).catch(() => {});
    clearAuthSession();
    setCurrentUser(null);
  };

  if (!currentUser) {
    return <Login onLogin={handleLogin} />;
  }

  return <Dashboard user={currentUser} onLogout={handleLogout} />;
}

function getAdminBadge(userName, role) {
  if (role === "admin" || role === "administrator") return "AD";
  if (role === "barangay_staff") return "LG";

  const words = (userName || "Operations Team").trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return "AD";
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();

  return words.slice(0, 2).map((word) => word[0]).join("").toUpperCase();
}

function Dashboard({ user, onLogout }) {
  const userName = user.name || "Operations Team";
  const isBarangayStaff = user.role === "barangay_staff";
  const navGroups = getNavigationGroups(user.role);
  const adminBadge = getAdminBadge(userName, user.role);
  const [page, setPage] = useState("overview");
  const [drawer, setDrawer] = useState(false);
  const [query, setQuery] = useState("");
  const [modal, setModal] = useState(null);
  const [issues, setIssues] = useState([]);
  const [users, setUsers] = useState([]);
  const [teams, setTeams] = useState([]);
  const [overviewData, setOverviewData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [apiError, setApiError] = useState("");
  const [toast, setToast] = useState(null);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [readNotificationIds, setReadNotificationIds] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem("infratrack.readNotifications") || "[]");
    } catch {
      return [];
    }
  });
  const notificationRef = useRef(null);
  const toastSequence = useRef(0);
  const showToast = (message) => setToast({ id: ++toastSequence.current, message });

  useEffect(() => {
    let active = true;

    const refreshDashboard = async () => {
      try {
        const scope = `?userId=${encodeURIComponent(user.id)}`;
        const [issueResponse, userResponse, teamResponse] = await Promise.all([
          apiFetch(`/issues${scope}`),
          apiFetch(`/users${scope}`),
          apiFetch("/teams"),
        ]);
        if (!issueResponse.ok || !userResponse.ok || !teamResponse.ok) {
          throw new Error(`API request failed (${issueResponse.status}/${userResponse.status}/${teamResponse.status})`);
        }
        const [issueData, userData, teamData] = await Promise.all([issueResponse.json(), userResponse.json(), teamResponse.json()]);
        const overviewResponse = await apiFetch(`/overview${scope}`);
        if (!overviewResponse.ok) throw new Error(`API request failed (${overviewResponse.status})`);
        const overviewData = await overviewResponse.json();
        if (active) {
          setIssues(issueData.issues ?? []);
          setUsers(userData.users ?? []);
          setTeams(teamData.teams ?? []);
          setOverviewData(overviewData);
          setApiError("");
        }
      } catch (error) {
        if (active) {
          setApiError(error instanceof Error ? error.message : "Could not connect to the API");
        }
      } finally {
        if (active) setIsLoading(false);
      }
    };

    const stopPolling = startVisiblePolling(refreshDashboard, {
      documentRef: document,
      intervalMs: 30_000,
    });
    return () => {
      active = false;
      stopPolling();
    };
  }, [isBarangayStaff, user.id]);

  useEffect(() => {
    if (!toast) return undefined;
    const timeoutId = window.setTimeout(() => setToast(null), 3000);
    return () => window.clearTimeout(timeoutId);
  }, [toast?.id]);

  const pageMeta = {
    overview: [isBarangayStaff ? user.barangay : "Local Government Unit", "Overview"],
    queue: [isBarangayStaff ? user.barangay : "Operations", "Issue Queue"],
    map: [isBarangayStaff ? user.barangay : "Operations", "Infrastructure Map"],
    analytics: [isBarangayStaff ? user.barangay : "Operations", "Analytics & Reports"],
    users: [isBarangayStaff ? user.barangay || "Barangay" : "Administration", isBarangayStaff ? "Residents" : "User Management"],
    announce: [isBarangayStaff ? user.barangay : "Administration", "Public Advisory"],
    published: [isBarangayStaff ? user.barangay : "Administration", "Published Advisories"],
    settings: [isBarangayStaff ? "Account" : "Administration", isBarangayStaff ? "Account settings" : "Settings"],
    logs: [isBarangayStaff ? user.barangay : "Administration", "Activity Logs"],
  };

  const filteredIssues = useMemo(
    () =>
      issues.filter((issue) =>
        `${issue.title ?? ""} ${issue.location ?? ""} ${issue.id ?? ""} ${issue.public_id ?? ""}`
          .toLowerCase()
          .includes(query.trim().toLowerCase()),
      ),
    [issues, query],
  );

  const notifications = useMemo(
    () => [...issues].sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, 5),
    [issues],
  );
  const unreadNotificationCount = notifications.filter((issue) => !readNotificationIds.includes(issue.public_id)).length;

  useEffect(() => {
    const closeNotifications = (event) => {
      if (notificationRef.current && !notificationRef.current.contains(event.target)) {
        setNotificationsOpen(false);
      }
    };
    document.addEventListener("mousedown", closeNotifications);
    return () => document.removeEventListener("mousedown", closeNotifications);
  }, []);

  const markNotificationsRead = () => {
    const ids = notifications.map((issue) => issue.public_id);
    setReadNotificationIds((current) => {
      const next = [...new Set([...current, ...ids])];
      localStorage.setItem("infratrack.readNotifications", JSON.stringify(next));
      return next;
    });
  };

  const navigate = (next) => {
    if (!canAccessAdminPage(user.role, next)) return;
    setPage(next);
    setDrawer(false);
  };

  const handleSearch = (event) => {
    const nextQuery = event.target.value;
    setQuery(nextQuery);
    if (nextQuery.trim() && page !== "queue") {
      setPage("queue");
    }
  };

  const handleLogout = () => {
    setDrawer(false);
    onLogout();
  };

  return (
    <div className="app-shell">
      <aside className={`sidebar ${drawer ? "open" : ""}`}>
        <div className="brand">
          <div className="brand-mark">
            <Icon icon={Building2} size={21} />
          </div>
          <div>
            <strong>InfraTrack</strong>
            <small>
              {isBarangayStaff
                ? `${user.barangay || "Barangay"} Staff Portal`
                : "Admin Portal · Mati"}
            </small>
          </div>
        </div>

        {navGroups.map((group) => (
          <div className="nav-group" key={group.label}>
            <span className="nav-label">{group.label}</span>
            {group.items.map(([id, label]) => (
              <button
                className={`nav-link ${page === id ? "active" : ""}`}
                key={id}
                onClick={() => navigate(id)}
              >
                <Icon icon={navIcons[id]} />
                <span>{label}</span>
                {id === "queue" && <b>{filteredIssues.length}</b>}
              </button>
            ))}
          </div>
        ))}

        <div className="sidebar-spacer" />
        <button className="nav-link" type="button" onClick={() => navigate("settings")}>
          <Icon icon={Settings} />
          <span>{isBarangayStaff ? "Account settings" : "Settings"}</span>
        </button>
        <button className="nav-link" type="button" onClick={handleLogout}>
          <Icon icon={LogOut} />
          <span>Log out</span>
        </button>
      </aside>

      {drawer && (
        <button
          className="scrim"
          aria-label="Close menu"
          onClick={() => setDrawer(false)}
        />
      )}

      <main className="main-content">
        <header className="topbar">
          <button className="icon-button menu-button" onClick={() => setDrawer(true)}>
            <Icon icon={Menu} />
          </button>
          <div>
            <div className="eyebrow">{pageMeta[page][0]}</div>
            <h1>{pageMeta[page][1]}</h1>
          </div>
          <label className="search">
            <Icon icon={Search} size={17} />
            <input
              value={query}
              onChange={handleSearch}
              placeholder="Search infrastructure ID, street, or barangay…"
            />
          </label>
          <div className="top-actions">
            <button
              className="primary-button"
              onClick={() =>
                setModal({
                  type: "walkin",
                })
              }
            >
              <Icon icon={Flag} size={17} /> Log walk-in report
            </button>
            <div className="notification-menu" ref={notificationRef}>
              <button
                className={`icon-button notification ${notificationsOpen ? "active" : ""}`}
                type="button"
                aria-label={`Notifications${unreadNotificationCount ? `, ${unreadNotificationCount} unread` : ""}`}
                aria-expanded={notificationsOpen}
                onClick={() => setNotificationsOpen((open) => !open)}
              >
                <Icon icon={Bell} />
                {unreadNotificationCount > 0 && <i />}
              </button>
              {notificationsOpen && (
                <div className="notification-dropdown" role="dialog" aria-label="Notifications">
                  <div className="notification-heading">
                    <div>
                      <strong>Notifications</strong>
                      <span>{unreadNotificationCount ? `${unreadNotificationCount} unread` : "All caught up"}</span>
                    </div>
                    {unreadNotificationCount > 0 && (
                      <button type="button" onClick={markNotificationsRead}>Mark all read</button>
                    )}
                  </div>
                  <div className="notification-list">
                    {notifications.map((issue) => {
                      const unread = !readNotificationIds.includes(issue.public_id);
                      return (
                        <button
                          className={`notification-item ${unread ? "unread" : ""}`}
                          type="button"
                          key={issue.public_id}
                          onClick={() => {
                            setModal({ type: "issue", ...issue });
                            setNotificationsOpen(false);
                          }}
                        >
                          <span className={`notification-status ${issue.status === "Resolved" ? "resolved" : "pending"}`} />
                          <span className="notification-copy">
                            <strong>{issue.title}</strong>
                            <small>{issue.status} · {issue.location}</small>
                            <em>{new Date(issue.created_at).toLocaleString()}</em>
                          </span>
                          {unread && <b aria-label="Unread" />}
                        </button>
                      );
                    })}
                    {!notifications.length && <p className="notification-empty">No infrastructure updates yet.</p>}
                  </div>
                  <button className="notification-footer" type="button" onClick={() => { navigate("queue"); setNotificationsOpen(false); }}>
                    View issue queue <ChevronRight size={15} />
                  </button>
                </div>
              )}
            </div>
            <button type="button" className="icon-button" aria-label="Help" onClick={() => setModal({ type: "help" })}>
              <Icon icon={HelpCircle} />
            </button>
            <div className="admin-avatar">{adminBadge}</div>
          </div>
        </header>

        <section className="content">
          {apiError && (
            <div
              role="alert"
              style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16, marginBottom: 20, padding: "12px 16px", borderRadius: 12, background: "#fff1ed", color: "#9f351e", border: "1px solid #f2c2b5" }}
            >
              <span>API unavailable at {API_BASE}: {apiError}</span>
              <button type="button" className="secondary-button" onClick={() => window.location.reload()}>
                Retry
              </button>
            </div>
          )}
          <PageContent
            page={page}
            issues={filteredIssues}
            users={users}
            isLoading={isLoading}
            onOpenIssue={(issue) => setModal({ type: "issue", ...issue, teams })}
            onOpenUser={(user) => setModal({ type: "user", user })}
            onNavigate={navigate}
            onNotify={showToast}
            overviewData={overviewData}
            user={user}
          />
        </section>
      </main>

      {modal && (
        <Modal
          data={modal}
          onClose={() => setModal(null)}
          onUserSave={async (changes) => {
            const response = await apiFetch(`/users/${modal.user.id}/moderation`, {
              method: "PATCH",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ ...changes, adminId: user.id }),
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data.error || "Could not save moderation action.");
            const usersResponse = await apiFetch(`/users?userId=${encodeURIComponent(user.id)}`);
            if (!usersResponse.ok) throw new Error("Could not refresh user accounts.");
            setUsers((await usersResponse.json()).users ?? []);
            setModal(null);
          }}
          onSave={async (changes) => {
            if (modal.type === "walkin") {
              const response = await apiFetch(`/reports`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(changes),
              });
              const data = await response.json();
              if (!response.ok) throw new Error(data.error || "Could not save walk-in report.");
              const issueResponse = await apiFetch(`/issues?userId=${encodeURIComponent(user.id)}`);
              if (!issueResponse.ok) throw new Error("Report was saved, but the report list could not be refreshed.");
              setIssues((await issueResponse.json()).issues ?? []);
              setModal(null);
              return;
            }
            if (modal.type === "issue" && modal.id && modal.id !== "Walk-in report") {
              const updateResponse = await apiFetch(`/issues/${modal.id}`, {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ ...changes, adminId: user.id }),
              });
              const updateData = await updateResponse.json();
              if (!updateResponse.ok) {
                throw new Error(updateData.error || "Could not update report.");
              }
              const response = await apiFetch(`/issues?userId=${encodeURIComponent(user.id)}`);
              if (!response.ok) throw new Error("Report was saved, but the report list could not be refreshed.");
              setIssues((await response.json()).issues ?? []);
              const previousStatus = modal.status === "New report" ? "Reported" : modal.status;
              showToast(changes.status === "Archived"
                ? "Report archived."
                : changes.status !== previousStatus
                  ? `Report status changed to ${changes.status}.`
                  : "Report changes saved.");
            }
            setModal(null);
          }}
        />
      )}
      {toast && (
        <div className="action-toast" role="status" aria-live="polite">
          <CheckCircle2 size={18} />
          <span>{toast.message}</span>
        </div>
      )}
    </div>
  );
}

function PageContent({ page, issues, users, isLoading, onOpenIssue, onOpenUser, onNavigate, onNotify, overviewData, user }) {
  if (isLoading) return <DashboardLoading />;

  if (!canAccessAdminPage(user?.role, page)) {
    return (
      <Overview
        issues={issues}
        overviewData={overviewData}
        onOpenIssue={onOpenIssue}
        onNavigate={onNavigate}
        user={user}
      />
    );
  }

  if (page === "queue") return <IssueQueuePage issues={issues} onOpenIssue={onOpenIssue} />;
  if (page === "map") return <MapPage issues={issues} onOpenIssue={onOpenIssue} user={user} />;
  if (page === "analytics") return <AnalyticsLive user={user} />;
  if (page === "users") return <UsersPage users={users} onOpenUser={onOpenUser} user={user} />;
  if (page === "announce") return <AdvisoryPage user={user} onNotify={onNotify} onViewAll={() => onNavigate("published")} />;
  if (page === "published") return <AdvisoryPage user={user} onNotify={onNotify} publishedOnly />;
  if (page === "logs") return <SettingsPage user={user} logsOnly />;
  if (page === "settings") return <SettingsPage user={user} />;

  return <Overview issues={issues} overviewData={overviewData} onOpenIssue={onOpenIssue} onNavigate={onNavigate} user={user} />;
}

function DashboardLoading({ message = "Loading your workspace…" }) {
  return (
    <div className="dashboard-loading" role="status" aria-label="Loading dashboard data">
      <span className="loading-status">{message}</span>
      <div className="loading-kpis" aria-hidden="true">
        {Array.from({ length: 4 }, (_, index) => <div className="card loading-kpi" key={index}><i className="skeleton-block" /><i className="skeleton-line" /><i className="skeleton-value" /></div>)}
      </div>
      <div className="card loading-table" aria-hidden="true">
        <i className="skeleton-line loading-table-heading" />
        {Array.from({ length: 5 }, (_, index) => <i className="skeleton-line loading-table-row" key={index} />)}
      </div>
    </div>
  );
}

function Overview({ issues, overviewData, onOpenIssue, onNavigate, user }) {
  const summary = overviewData?.summary;
  return (
    <>
      <div className="kpi-grid">
        <Kpi icon={FileText} label="Total reports" value={summary?.total ?? "—"} tag={user?.role === "barangay_staff" ? `Assigned to ${user.barangay}` : "All database reports"} tone="teal" />
        <Kpi icon={AlertTriangle} label="Pending tasks" value={summary?.pending ?? "—"} tag="Needs review" tone="clay" />
        <Kpi icon={Activity} label="Avg. resolution time" value={<><span>{summary?.avgResolutionDays ?? "—"}</span> <small>days</small></>} tag="Resolved reports" tone="green" />
        <Kpi icon={CheckCircle2} label="Completion rate" value={`${summary?.completionRate ?? "—"}%`} tag="Resolved issues" tone="amber" />
      </div>

      <div className="two-column">
        <MapCard issues={issues} onOpenIssue={onOpenIssue} user={user} />
        <ActivityCard activities={overviewData?.recent ?? []} onNavigate={onNavigate} />
      </div>

      <div className="two-column lower">
        <CategoryCard categories={overviewData?.categories ?? []} />
        <TeamCard teams={overviewData?.teams ?? []} />
      </div>


      <div className="section-heading">
        Recent reports <button onClick={() => onNavigate("queue")}>View issue queue <ChevronRight size={15} /></button>
      </div>

      <IssueTable issues={issues.slice(0, 3)} onOpenIssue={onOpenIssue} />
    </>
  );
}

function Kpi({ icon, label, value, tag, tone }) {
  return (
    <article className="kpi card">
      <div className={`kpi-icon ${tone}`}>
        <Icon icon={icon} />
      </div>
      <span className={`tag ${tone}`}>{tag}</span>
      <p>{label}</p>
      <strong>{value}</strong>
    </article>
  );
}

function MapCard({ issues, onOpenIssue, user }) {
  const [filter, setFilter] = useState("all");

  const visibleIssues = useMemo(() => {
    if (filter === "all") return issues;
    return issues.filter((issue) => {
      if (filter === "unassigned") {
        return !issue.assignedTeam || issue.assignedTeam === "Unassigned";
      }
      if (filter === "resolved") {
        return issue.status === "Resolved";
      }
      return issue.severity === filter || issue.status === filter;
    });
  }, [filter, issues]);

  const filterOptions = [
    ["all", "All"],
    ["Critical", "Critical"],
    ["High", "High"],
    ["Medium", "Medium"],
    ["resolved", "Resolved"],
    ["unassigned", "Unassigned"],
  ];

  return (
    <article className="card map-card">
      <div className="card-head">
        <h2>Active infrastructure issues</h2>
        <div className="filters" style={{ marginBottom: 0 }}>
          {filterOptions.map(([value, label]) => (
            <button
              key={value}
              type="button"
              className={`filter ${filter === value ? "active" : ""}`}
              onClick={() => setFilter(value)}
            >
              {label}
            </button>
          ))}
        </div>
      </div>
      <LeafletInfrastructureMap issues={visibleIssues} onOpenIssue={onOpenIssue} barangay={user?.barangay} />
    </article>
  );
}

function ActivityCard({ activities, onNavigate }) {
  return (
    <article className="card">
      <div className="card-head">
        <h2>Recent activity</h2>
        <button type="button" className="text-link" onClick={() => onNavigate("queue")}>
          View all
        </button>
      </div>
      {activities.map((activity) => (
        <div className="activity-item" key={activity.public_id}>
          <div className={`activity-icon ${activity.status === "Resolved" ? "done" : "new"}`}>
            <Icon icon={activity.status === "Resolved" ? CheckCircle2 : Flag} />
          </div>
          <div>
            <b>{activity.title}</b>
            <p>{activity.status} · {activity.category} · {activity.location}</p>
            <small>{new Date(activity.created_at).toLocaleString()} · #{activity.public_id}</small>
          </div>
        </div>
      ))}
      {!activities.length && <p className="muted">No recent reports.</p>}
    </article>
  );
}

function CategoryCard({ categories }) {
  const max = Math.max(...categories.map((item) => item.count), 1);
  return (
    <article className="card">
      <div className="card-head">
        <h2>Reports by category</h2>
        <span className="muted">Last 30 days</span>
      </div>
      {categories.map((item, index) => (
        <div className="bar-row" key={item.name}>
          <span>{item.name}</span>
          <div className="bar">
            <i className={["clay", "amber", "teal", "purple", "green"][index % 5]} style={{ width: `${(item.count / max) * 100}%` }} />
          </div>
          <b>{item.count}</b>
        </div>
      ))}
      {!categories.length && <p className="muted">No category data.</p>}
    </article>
  );
}

function TeamCard({ teams }) {
  return (
    <article className="card">
      <div className="card-head">
        <h2>Team workload</h2>
        <span className="muted">Active assignments</span>
      </div>
      {teams.map((team) => (
        <div className="activity-item" key={team.name}>
          <div className="activity-icon assign">
            <Icon icon={team.name === "Unassigned" ? Flag : Wrench} />
          </div>
          <div>
            <b>{team.name}</b>
            <p>{team.activeCount} active work orders · {team.location || "Mati City"}</p>
          </div>
        </div>
      ))}
    </article>
  );
}

function Analytics() {
  const sentimentBreakdown = [
    ["5", 61, "green"],
    ["4", 21, "green"],
    ["3", 9, "amber"],
    ["2", 6, "clay"],
    ["1", 3, "red"],
  ];

  const hotspotData = [
    ["Purok 3, Brgy. Dawan", "Water service interruptions", 38],
    ["Rizal Street", "Road surface damage", 27],
    ["Public Market area", "Drainage blockage", 21],
    ["J.P. Laurel Ave.", "Streetlight outages", 14],
  ];

  const teamEfficiency = [
    ["Team Alpha", 92, "clay"],
    ["Crew Delta", 88, "amber"],
    ["Electrician U4", 95, "purple"],
    ["Water District", 79, "teal"],
  ];

  return (
    <>
      <div className="analytics-grid">
        <article className="card analytics-panel">
          <div className="card-head">
            <h2>Sentiment analysis</h2>
            <span className="muted">From resolution ratings</span>
          </div>

          <div className="sentiment-gauge">
            <div className="sentiment-ring">
              <strong>4.4</strong>
              <span>AVG. STAR</span>
            </div>
          </div>

          <div className="rating-bars">
            {sentimentBreakdown.map(([star, pct, tone]) => (
              <div key={star} className="rating-row">
                <span>
                  {star} <b>★</b>
                </span>
                <div className="rating-track">
                  <i className={tone} style={{ width: `${pct}%` }} />
                </div>
                <em>{pct}%</em>
              </div>
            ))}
          </div>

          <p className="sentiment-note">
            940 residents rated a completed repair this quarter. 82% gave 4–5 stars,
            read as <b>positive</b> sentiment; 9% neutral; 9% negative — negative
            ratings are auto-flagged for a follow-up review.
          </p>
        </article>

        <article className="card analytics-panel">
          <div className="card-head">
            <h2>Resolution time trend</h2>
            <span className="muted">Weeks</span>
          </div>

          <svg className="trend-chart" viewBox="0 0 260 120" preserveAspectRatio="none" aria-label="Resolution trend chart">
            <polyline
              points="0,80 40,70 80,74 120,55 160,48 200,38 240,30"
              fill="none"
              stroke="var(--teal)"
              strokeWidth="3"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            <g fill="var(--teal)">
              <circle cx="240" cy="30" r="4" />
            </g>
            <line x1="0" y1="105" x2="260" y2="105" stroke="var(--line)" strokeWidth="1" />
          </svg>

          <p className="trend-caption">
            Avg. resolution improved from 5.1 to 3.2 days over 7 weeks.
          </p>
        </article>

        <article className="card analytics-panel">
          <div className="card-head">
            <h2>Recurring hotspots</h2>
          </div>

          {hotspotData.map(([place, detail, count], index) => (
            <div className="hotspot" key={place}>
              <b>{String(index + 1).padStart(2, "0")}</b>
              <span>
                <strong>{place}</strong>
                <small>{detail}</small>
              </span>
              <em>{count}</em>
            </div>
          ))}
        </article>
      </div>

      <div className="analytics-lower">
        <article className="card analytics-panel">
          <div className="card-head">
            <h2>Response efficiency by team</h2>
          </div>

          {teamEfficiency.map(([team, pct, tone]) => (
            <div key={team} className="rating-row team-efficiency-row">
              <span className="team-label">{team}</span>
              <div className="rating-track">
                <i className={tone} style={{ width: `${pct}%` }} />
              </div>
              <em>{pct}%</em>
            </div>
          ))}

          <p className="sentiment-note efficiency-note">
            Efficiency reflects on-time completion against assigned target dates, used
            for resource allocation planning.
          </p>
        </article>

        <article className="card analytics-panel">
          <div className="card-head">
            <h2>Generate printable report</h2>
          </div>

          <div className="report-generator">
            <div className="report-field">
              <label>Report type</label>
              <select defaultValue="Infrastructure summary">
                <option>Infrastructure summary</option>
                <option>Team performance</option>
                <option>Sentiment &amp; feedback</option>
                <option>Barangay hotspot summary</option>
              </select>
            </div>

            <div className="report-field">
              <label>Frequency</label>
              <select defaultValue="Monthly">
                <option>Daily</option>
                <option>Weekly</option>
                <option>Monthly</option>
                <option>Yearly</option>
              </select>
            </div>

            <button type="button" className="primary-button report-button">
              <Icon icon={FileText} size={16} /> Generate PDF
            </button>
          </div>

          <p className="sentiment-note">
            Printable summaries support recurring reporting to the City Engineering Office
            and CDRRMO for planning and budget review.
          </p>
        </article>
      </div>
    </>
  );
}

function AnalyticsLive({ user }) {
  const [period, setPeriod] = useState("month");
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let active = true;
    setIsLoading(true);
    apiFetch(`/analytics?period=${period}&userId=${encodeURIComponent(user?.id || "")}`)
      .then(async (response) => {
        const body = await response.json();
        if (!response.ok) throw new Error(body.error || "Could not load analytics");
        if (active) setData(body);
      })
      .catch((loadError) => { if (active) setError(loadError.message); })
      .finally(() => { if (active) setIsLoading(false); });
    return () => { active = false; };
  }, [period, user?.id]);

  if (!data && isLoading) return <DashboardLoading message="Loading analytics…" />;

  const maxCategory = Math.max(...(data?.categories ?? []).map((item) => Number(item.count)), 1);
  const maxTrend = Math.max(...(data?.trend ?? []).map((item) => Number(item.count)), 1);
  const trendPoints = (data?.trend ?? []).map((item, index, items) => {
    const x = items.length === 1 ? 130 : (index / (items.length - 1)) * 240;
    const y = 105 - (Number(item.count) / maxTrend) * 80;
    return `${x},${y}`;
  }).join(" ");

  return (
    <>
      <div className="card analytics-period-bar">
        <strong>Report period</strong>
        {[["day", "Day"], ["week", "Week"], ["month", "Month"], ["year", "Year"]].map(([value, label]) => (
          <button key={value} className={`filter ${period === value ? "active" : ""}`} onClick={() => setPeriod(value)}>{label}</button>
        ))}
        <span className="muted" role={isLoading ? "status" : undefined}>
          {isLoading ? "Updating analytics…" : `Live MySQL data · ${data?.periodLabel || period}`}
        </span>
        <button type="button" className="primary-button print-button" onClick={() => window.print()}>
          Print / Save PDF
        </button>
      </div>
      {error && <div className="login-error" role="alert">{error}</div>}
      <div className="kpi-grid">
        <Kpi icon={FileText} label="Reports in period" value={data?.summary.total ?? "—"} tag="Database total" tone="teal" />
        <Kpi icon={AlertTriangle} label="Reported" value={data?.summary.reported ?? "—"} tag="Needs review" tone="clay" />
        <Kpi icon={Activity} label="In progress" value={data?.summary.inProgress ?? "—"} tag="Active work" tone="green" />
        <Kpi icon={CheckCircle2} label="Resolved" value={data?.summary.resolved ?? "—"} tag="Completed" tone="amber" />
      </div>
      <div className="analytics-grid">
        <article className="card analytics-panel">
          <div className="card-head"><h2>Reports by category</h2><span className="muted">Selected period</span></div>
          {(data?.categories ?? []).map((item, index) => (
            <div className="bar-row" key={item.name}>
              <span>{item.name}</span><div className="bar"><i className={["clay", "amber", "teal", "purple", "green"][index % 5]} style={{ width: `${(Number(item.count) / maxCategory) * 100}%` }} /></div><b>{item.count}</b>
            </div>
          ))}
          {!data?.categories?.length && <p className="muted">No reports in this period.</p>}
        </article>
        <article className="card analytics-panel">
          <div className="card-head"><h2>Report trend</h2><span className="muted">{data?.periodLabel || "Period"}</span></div>
          <svg className="trend-chart" viewBox="0 0 260 120" preserveAspectRatio="none" aria-label="Report trend chart">
            {trendPoints && <polyline points={trendPoints} fill="none" stroke="var(--teal)" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />}
            <line x1="0" y1="105" x2="260" y2="105" stroke="var(--line)" strokeWidth="1" />
          </svg>
          <p className="trend-caption">{(data?.trend ?? []).length} time buckets · {data?.summary.total ?? 0} reports</p>
        </article>
        <article className="card analytics-panel">
          <div className="card-head"><h2>Hotspots</h2><span className="muted">Most reported locations</span></div>
          {(data?.hotspots ?? []).map((item, index) => <div className="hotspot" key={`${item.name}-${item.category}`}><b>{String(index + 1).padStart(2, "0")}</b><span><strong>{item.name}</strong><small>{item.category}</small></span><em>{item.count}</em></div>)}
          {!data?.hotspots?.length && <p className="muted">No hotspots in this period.</p>}
        </article>
      </div>
      <article className="card analytics-panel resident-rating-panel">
        <div className="card-head"><h2>Resident ratings</h2><span className="muted">Completed report feedback</span></div>
        <div className="sentiment-gauge"><div className="sentiment-ring"><strong>{data?.ratings.average || "—"}</strong><span>AVG. STAR</span></div></div>
        <p className="sentiment-note">{data?.ratings.total ?? 0} ratings recorded in the selected period.</p>
      </article>
      <article className="card analytics-panel thematic-analysis-panel">
        <div className="card-head">
          <h2>Thematic analysis</h2>
          <span className="muted">{data?.summary.total ?? 0} reports analyzed</span>
        </div>
        <p className="thematic-analysis-note">
          Primary themes are identified from report categories, titles, and descriptions. Each report is counted once.
        </p>
        {(data?.themes ?? []).map((theme, index) => (
          <div className="thematic-row" key={theme.name}>
            <div className="thematic-row-heading">
              <strong>{theme.name}</strong>
              <span>{theme.count} · {theme.percentage}%</span>
            </div>
            <div className="thematic-track" aria-label={`${theme.name}: ${theme.count} reports, ${theme.percentage}%`}>
              <i className={["clay", "amber", "teal", "purple", "green"][index % 5]} style={{ width: `${theme.percentage}%` }} />
            </div>
            <small>{theme.description}</small>
          </div>
        ))}
        {!data?.themes?.length && <p className="muted">No reports to analyze in this period.</p>}
      </article>
    </>
  );
}
