import { useEffect, useMemo, useRef, useState } from "react";
import "leaflet/dist/leaflet.css";
import {
  Activity,
  AlertTriangle,
  BarChart3,
  Bell,
  Camera,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  ClipboardList,
  CircleAlert,
  FileText,
  Flag,
  HelpCircle,
  LayoutDashboard,
  LogOut,
  Map,
  MapPin,
  MapPinPlusInside,
  Menu,
  Megaphone,
  Monitor,
  Moon,
  Palette,
  Search,
  Settings,
  Star,
  ScrollText,
  Sun,
  ShieldAlert,
  TriangleAlert,
  Layers3,
  UserRoundX,
  UserRound,
  Users,
  Wrench,
} from "lucide-react";

import { Modal } from "./components/Modals";
import IssueQueuePage from "./pages/IssueQueuePage";
import MapPage, { LeafletInfrastructureMap } from "./pages/MapPage";
import UsersPage from "./pages/UsersPage";
import AdvisoryPage from "./pages/AdvisoryPage";
import SettingsPage from "./pages/SettingsPage";
import Login from "./Login";
import { API_BASE, apiFetch } from "./api";
import {
  clearAuthSession,
  getStoredAuthSession,
  updateStoredAuthUser,
} from "./authSession";
import { canAccessAdminPage, getNavigationGroups } from "./roleNavigation";
import { startVisiblePolling } from "./visiblePolling";
import {
  initializeAppearance,
  readAppearance,
  saveAppearance,
} from "./appearance";
import { getDashboardSummary } from "../dashboardSummary.js";
import {
  formatAnalyticsTrendLabel,
  getAnalyticsCategoryRows,
} from "./analyticsDisplay.js";

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
  useEffect(() => initializeAppearance(), []);

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

  const handleUserUpdated = (user) => {
    updateStoredAuthUser(user);
    setCurrentUser(user);
  };

  if (!currentUser) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <Dashboard
      user={currentUser}
      onLogout={handleLogout}
      onUserUpdated={handleUserUpdated}
    />
  );
}

function getAdminBadge(userName, role) {
  if (role === "admin" || role === "administrator") return "AD";
  if (role === "barangay_staff") return "LG";

  const words = (userName || "Operations Team")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (words.length === 0) return "AD";
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();

  return words
    .slice(0, 2)
    .map((word) => word[0])
    .join("")
    .toUpperCase();
}

async function fetchUserReports(residentId) {
  const response = await apiFetch(`/users/${residentId}/reports`);
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || "Could not load recent reports.");
  }
  return data.reports ?? [];
}

function Dashboard({ user, onLogout, onUserUpdated }) {
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
  const [profileOpen, setProfileOpen] = useState(false);
  const [appearance, setAppearance] = useState(readAppearance);
  const [photoUploading, setPhotoUploading] = useState(false);
  const [profileMenuError, setProfileMenuError] = useState("");
  const [readNotificationIds, setReadNotificationIds] = useState(() => {
    try {
      return JSON.parse(
        localStorage.getItem("infratrack.readNotifications") || "[]",
      );
    } catch {
      return [];
    }
  });
  const notificationRef = useRef(null);
  const profileMenuRef = useRef(null);
  const profilePhotoInputRef = useRef(null);
  const toastSequence = useRef(0);
  const showToast = (message) =>
    setToast({ id: ++toastSequence.current, message });

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
          throw new Error(
            `API request failed (${issueResponse.status}/${userResponse.status}/${teamResponse.status})`,
          );
        }
        const [issueData, userData, teamData] = await Promise.all([
          issueResponse.json(),
          userResponse.json(),
          teamResponse.json(),
        ]);
        const overviewResponse = await apiFetch(`/overview${scope}`);
        if (!overviewResponse.ok)
          throw new Error(`API request failed (${overviewResponse.status})`);
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
          setApiError(
            error instanceof Error
              ? error.message
              : "Could not connect to the API",
          );
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
    overview: [
      isBarangayStaff ? user.barangay : "Local Government Unit",
      "Overview",
    ],
    queue: [isBarangayStaff ? user.barangay : "Operations", "Issue Queue"],
    map: [isBarangayStaff ? user.barangay : "Operations", "Infrastructure Map"],
    analytics: [
      isBarangayStaff ? user.barangay : "Operations",
      "Analytics & Reports",
    ],
    users: [
      isBarangayStaff ? user.barangay || "Barangay" : "Administration",
      isBarangayStaff ? "Residents" : "User Management",
    ],
    announce: [
      isBarangayStaff ? user.barangay : "Administration",
      "Public Advisory",
    ],
    published: [
      isBarangayStaff ? user.barangay : "Administration",
      "Published Advisories",
    ],
    settings: [
      isBarangayStaff ? "Account" : "Administration",
      isBarangayStaff ? "Account settings" : "Settings",
    ],
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
    () =>
      [...issues]
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, 5),
    [issues],
  );
  const unreadNotificationCount = notifications.filter(
    (issue) => !readNotificationIds.includes(issue.public_id),
  ).length;

  useEffect(() => {
    const closeNotifications = (event) => {
      if (
        notificationRef.current &&
        !notificationRef.current.contains(event.target)
      ) {
        setNotificationsOpen(false);
      }
    };
    document.addEventListener("mousedown", closeNotifications);
    return () => document.removeEventListener("mousedown", closeNotifications);
  }, []);

  useEffect(() => {
    const closeProfileMenu = (event) => {
      if (
        profileMenuRef.current &&
        !profileMenuRef.current.contains(event.target)
      ) {
        setProfileOpen(false);
      }
    };
    const closeOnEscape = (event) => {
      if (event.key === "Escape") setProfileOpen(false);
    };
    document.addEventListener("mousedown", closeProfileMenu);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("mousedown", closeProfileMenu);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, []);

  const markNotificationsRead = () => {
    const ids = notifications.map((issue) => issue.public_id);
    setReadNotificationIds((current) => {
      const next = [...new Set([...current, ...ids])];
      localStorage.setItem(
        "infratrack.readNotifications",
        JSON.stringify(next),
      );
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

  const openSettings = (focusAppearance = false) => {
    navigate("settings");
    setProfileOpen(false);
    if (focusAppearance) {
      window.setTimeout(() => {
        document.getElementById("appearance-title")?.scrollIntoView({
          behavior: "smooth",
          block: "start",
        });
      }, 0);
    }
  };

  const updateProfileTheme = (theme, transitionOrigin) => {
    const next = saveAppearance(
      { ...appearance, theme },
      undefined,
      undefined,
      window.matchMedia("(prefers-color-scheme: dark)").matches,
      true,
      transitionOrigin,
    );
    setAppearance(next);
  };

  const uploadProfilePhoto = async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;

    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      setProfileMenuError("Choose a JPG, PNG, or WebP profile photo.");
      return;
    }
    if (file.size > 8 * 1024 * 1024) {
      setProfileMenuError("Profile photos must be 8 MB or smaller.");
      return;
    }

    setPhotoUploading(true);
    setProfileMenuError("");
    try {
      const body = new FormData();
      body.append("photo", file);
      const response = await apiFetch("/mobile/profile/photo", {
        method: "POST",
        body,
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || "Could not save the profile photo.");
      }
      onUserUpdated(data.user);
    } catch (error) {
      setProfileMenuError(error.message || "Could not save the profile photo.");
    } finally {
      setPhotoUploading(false);
    }
  };

  return (
    <div className="app-shell">
      <aside className={`sidebar ${drawer ? "open" : ""}`}>
        <div className="brand">
          <div className="brand-mark">
            <Icon icon={MapPinPlusInside} size={22} />
          </div>
          <div>
            <strong className="brand-wordmark">
              <span>Infra</span>
              <span className="brand-wordmark-accent">Track</span>
            </strong>
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
                data-tour-target={`nav-${id}`}
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
        <button
          className="nav-link"
          type="button"
          onClick={() => navigate("settings")}
        >
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
          <button
            className="icon-button menu-button"
            onClick={() => setDrawer(true)}
          >
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
              data-tour-target="walkin-report"
              className="primary-button"
              onClick={() =>
                setModal({
                  type: "walkin",
                })
              }
            >
              <Icon icon={Flag} size={17} /> Log walk-in report
            </button>
            <div
              className="notification-menu"
              data-tour-target="notifications"
              ref={notificationRef}
            >
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
                <div
                  className="notification-dropdown"
                  role="dialog"
                  aria-label="Notifications"
                >
                  <div className="notification-heading">
                    <div>
                      <strong>Notifications</strong>
                      <span>
                        {unreadNotificationCount
                          ? `${unreadNotificationCount} unread`
                          : "All caught up"}
                      </span>
                    </div>
                    {unreadNotificationCount > 0 && (
                      <button type="button" onClick={markNotificationsRead}>
                        Mark all read
                      </button>
                    )}
                  </div>
                  <div className="notification-list">
                    {notifications.map((issue) => {
                      const unread = !readNotificationIds.includes(
                        issue.public_id,
                      );
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
                          <span
                            className={`notification-status ${issue.status === "Resolved" ? "resolved" : "pending"}`}
                          />
                          <span className="notification-copy">
                            <strong>{issue.title}</strong>
                            <small>
                              {issue.status} · {issue.location}
                            </small>
                            <em>
                              {new Date(issue.created_at).toLocaleString()}
                            </em>
                          </span>
                          {unread && <b aria-label="Unread" />}
                        </button>
                      );
                    })}
                    {!notifications.length && (
                      <p className="notification-empty">
                        No infrastructure updates yet.
                      </p>
                    )}
                  </div>
                  <button
                    className="notification-footer"
                    type="button"
                    onClick={() => {
                      navigate("queue");
                      setNotificationsOpen(false);
                    }}
                  >
                    View issue queue <ChevronRight size={15} />
                  </button>
                </div>
              )}
            </div>
            <button
              type="button"
              className="icon-button"
              data-tour-target="help"
              aria-label="Help"
              onClick={() => setModal({ type: "help" })}
            >
              <Icon icon={HelpCircle} />
            </button>
            <div className="profile-menu" ref={profileMenuRef}>
              <button
                className={`profile-menu-trigger ${profileOpen ? "active" : ""}`}
                type="button"
                aria-label={`Profile menu for ${userName}`}
                aria-haspopup="dialog"
                aria-expanded={profileOpen}
                onClick={() => {
                  if (!profileOpen) setAppearance(readAppearance());
                  setProfileMenuError("");
                  setProfileOpen((open) => !open);
                }}
              >
                <span className="admin-avatar">
                  {user.avatar_url ? (
                    <img src={user.avatar_url} alt="" />
                  ) : (
                    adminBadge
                  )}
                </span>
                <ChevronDown size={14} aria-hidden="true" />
              </button>
              {profileOpen && (
                <div
                  className="profile-dropdown"
                  role="dialog"
                  aria-label="Profile and appearance"
                >
                  <div className="profile-dropdown-identity">
                    <span className="profile-dropdown-avatar">
                      {user.avatar_url ? (
                        <img src={user.avatar_url} alt="" />
                      ) : (
                        adminBadge
                      )}
                    </span>
                    <span className="profile-dropdown-user">
                      <strong>{userName}</strong>
                      <small>{user.email || (isBarangayStaff ? user.barangay : "Mati City administrator")}</small>
                    </span>
                  </div>
                  <button
                    className="profile-dropdown-item"
                    type="button"
                    onClick={() => openSettings()}
                  >
                    <UserRound size={16} aria-hidden="true" />
                    <span>Account settings</span>
                  </button>
                  <button
                    className="profile-dropdown-item"
                    type="button"
                    disabled={photoUploading}
                    onClick={() => profilePhotoInputRef.current?.click()}
                  >
                    <Camera size={16} aria-hidden="true" />
                    <span>{photoUploading ? "Uploading photo…" : "Change photo"}</span>
                  </button>
                  <input
                    ref={profilePhotoInputRef}
                    className="profile-photo-input"
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    aria-label="Choose a profile photo"
                    onChange={uploadProfilePhoto}
                  />
                  {profileMenuError && (
                    <p className="profile-menu-error" role="alert">
                      {profileMenuError}
                    </p>
                  )}
                  <div className="profile-dropdown-divider" />
                  <div className="profile-theme-picker">
                    {[
                      ["light", "Light", Sun],
                      ["dark", "Dark", Moon],
                      ["system", "System", Monitor],
                    ].map(([theme, label, ThemeIcon]) => (
                      <button
                        key={theme}
                        className={`profile-theme-option ${appearance.theme === theme ? "selected" : ""}`}
                        type="button"
                        aria-pressed={appearance.theme === theme}
                        onClick={(event) =>
                          updateProfileTheme(theme, event.currentTarget)
                        }
                      >
                        <ThemeIcon size={15} aria-hidden="true" />
                        <span>{label}</span>
                      </button>
                    ))}
                  </div>
                  <button
                    className="profile-dropdown-item profile-appearance-link"
                    type="button"
                    onClick={() => openSettings(true)}
                  >
                    <Palette size={16} aria-hidden="true" />
                    <span>Appearance settings</span>
                    <ChevronRight size={15} aria-hidden="true" />
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        <section className="content">
          {apiError && (
            <div
              role="alert"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 16,
                marginBottom: 20,
                padding: "12px 16px",
                borderRadius: 12,
                background: "#fff1ed",
                color: "#9f351e",
                border: "1px solid #f2c2b5",
              }}
            >
              <span>
                API unavailable at {API_BASE}: {apiError}
              </span>
              <button
                type="button"
                className="secondary-button"
                onClick={() => window.location.reload()}
              >
                Retry
              </button>
            </div>
          )}
          <PageContent
            page={page}
            issues={filteredIssues}
            users={users}
            isLoading={isLoading}
            onOpenIssue={(issue) =>
              setModal({ type: "issue", ...issue, teams })
            }
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
          onUserVerification={async (decision) => {
            const response = await apiFetch(
              `/users/${modal.user.id}/verification`,
              {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ decision }),
              },
            );
            const data = await response.json();
            if (!response.ok) {
              throw new Error(
                data.error || "Could not update identity verification.",
              );
            }
            const usersResponse = await apiFetch(
              `/users?userId=${encodeURIComponent(user.id)}`,
            );
            if (!usersResponse.ok)
              throw new Error(
                "Verification was saved, but users could not be refreshed.",
              );
            setUsers((await usersResponse.json()).users ?? []);
            setModal(null);
          }}
          onFetchUserReports={fetchUserReports}
          onUserSave={async (changes) => {
            const response = await apiFetch(
              `/users/${modal.user.id}/moderation`,
              {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ ...changes, adminId: user.id }),
              },
            );
            const data = await response.json();
            if (!response.ok)
              throw new Error(
                data.error || "Could not save moderation action.",
              );
            const usersResponse = await apiFetch(
              `/users?userId=${encodeURIComponent(user.id)}`,
            );
            if (!usersResponse.ok)
              throw new Error("Could not refresh user accounts.");
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
              if (!response.ok)
                throw new Error(data.error || "Could not save walk-in report.");
              const issueResponse = await apiFetch(
                `/issues?userId=${encodeURIComponent(user.id)}`,
              );
              if (!issueResponse.ok)
                throw new Error(
                  "Report was saved, but the report list could not be refreshed.",
                );
              setIssues((await issueResponse.json()).issues ?? []);
              setModal(null);
              return;
            }
            if (
              modal.type === "issue" &&
              modal.id &&
              modal.id !== "Walk-in report"
            ) {
              const updateResponse = await apiFetch(`/issues/${modal.id}`, {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ ...changes, adminId: user.id }),
              });
              const updateData = await updateResponse.json();
              if (!updateResponse.ok) {
                throw new Error(updateData.error || "Could not update report.");
              }
              const response = await apiFetch(
                `/issues?userId=${encodeURIComponent(user.id)}`,
              );
              if (!response.ok)
                throw new Error(
                  "Report was saved, but the report list could not be refreshed.",
                );
              setIssues((await response.json()).issues ?? []);
              const previousStatus =
                modal.status === "New report" ? "Reported" : modal.status;
              showToast(
                changes.status === "Archived"
                  ? "Report archived."
                  : changes.status !== previousStatus
                    ? `Report status changed to ${changes.status}.`
                    : "Report changes saved.",
              );
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

function PageContent({
  page,
  issues,
  users,
  isLoading,
  onOpenIssue,
  onOpenUser,
  onNavigate,
  onNotify,
  overviewData,
  user,
}) {
  if (isLoading) return <DashboardLoading />;

  let pageView;
  if (!canAccessAdminPage(user?.role, page)) {
    pageView = (
      <Overview
        issues={issues}
        overviewData={overviewData}
        onOpenIssue={onOpenIssue}
        onNavigate={onNavigate}
        user={user}
      />
    );
  } else if (page === "queue") {
    pageView = <IssueQueuePage issues={issues} onOpenIssue={onOpenIssue} />;
  } else if (page === "map") {
    pageView = (
      <MapPage issues={issues} onOpenIssue={onOpenIssue} user={user} />
    );
  } else if (page === "analytics") {
    pageView = <AnalyticsLive user={user} />;
  } else if (page === "users") {
    pageView = <UsersPage users={users} onOpenUser={onOpenUser} user={user} />;
  } else if (page === "announce") {
    pageView = (
      <AdvisoryPage
        user={user}
        onNotify={onNotify}
        onViewAll={() => onNavigate("published")}
      />
    );
  } else if (page === "published") {
    pageView = <AdvisoryPage user={user} onNotify={onNotify} publishedOnly />;
  } else if (page === "logs") {
    pageView = <SettingsPage user={user} logsOnly />;
  } else if (page === "settings") {
    pageView = <SettingsPage user={user} />;
  } else {
    pageView = (
      <Overview
        issues={issues}
        overviewData={overviewData}
        onOpenIssue={onOpenIssue}
        onNavigate={onNavigate}
        user={user}
      />
    );
  }

  return (
    <div className="page-transition" key={page}>
      {pageView}
    </div>
  );
}

function DashboardLoading({ message = "Loading your workspace…" }) {
  return (
    <div
      className="dashboard-loading"
      role="status"
      aria-label="Loading dashboard data"
    >
      <span className="loading-status">{message}</span>
      <div className="loading-kpis" aria-hidden="true">
        {Array.from({ length: 4 }, (_, index) => (
          <div className="card loading-kpi" key={index}>
            <i className="skeleton-block" />
            <i className="skeleton-line" />
            <i className="skeleton-value" />
          </div>
        ))}
      </div>
      <div className="card loading-table" aria-hidden="true">
        <i className="skeleton-line loading-table-heading" />
        {Array.from({ length: 5 }, (_, index) => (
          <i className="skeleton-line loading-table-row" key={index} />
        ))}
      </div>
    </div>
  );
}

function Overview({ issues, overviewData, onOpenIssue, onNavigate, user }) {
  const summary = getDashboardSummary(issues);
  const now = new Date();
  const firstName = user?.name?.trim().split(/\s+/)[0] || "there";
  const greeting =
    now.getHours() < 12
      ? "Good morning"
      : now.getHours() < 18
        ? "Good afternoon"
        : "Good evening";
  const dateLabel = new Intl.DateTimeFormat(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric",
  }).format(now);
  const overviewArea =
    user?.role === "barangay_staff" && user.barangay
      ? user.barangay
      : "Mati City";
  const activeIssues = issues.filter(
    (issue) =>
      !["resolved", "rejected", "archived"].includes(
        String(issue.status || "").trim().toLowerCase(),
      ),
  );
  const criticalCount = activeIssues.filter(
    (issue) => issue.severity === "Critical",
  ).length;
  const unassignedCount = activeIssues.filter((issue) => {
    const assignedTeam = String(
      issue.assigned_team || issue.assignedTeam || "",
    ).trim();
    return !assignedTeam || assignedTeam.toLowerCase() === "unassigned";
  }).length;

  return (
    <div className="dashboard-overview">
      <section className="overview-welcome" aria-label="Welcome">
        <div className="overview-welcome-copy">
          <p className="overview-date-label">{dateLabel}</p>
          <h2>
            {greeting}, {firstName}.
          </h2>
          <div className={`overview-attention ${summary.activeCount === 0 ? "all-clear" : ""}`}>
            <span className="overview-attention-dot" />
            <span>
              {summary.activeCount === 0
                ? "You’re all caught up on active reports."
                : `${summary.activeCount} active ${summary.activeCount === 1 ? "report needs" : "reports need"} your attention.`}
            </span>
          </div>
        </div>
        <aside className="overview-operations-snapshot" aria-label="Operations snapshot">
          <div className="overview-snapshot-heading">
            <span className="overview-snapshot-location">
              <MapPin size={14} aria-hidden="true" />
              {overviewArea}
            </span>
            <span className="overview-snapshot-live">
              <i />
              Live overview
            </span>
          </div>
          <div className="overview-snapshot-metrics">
            <div>
              <strong>{summary.activeCount}</strong>
              <span>Active</span>
            </div>
            <div className={criticalCount ? "has-critical" : ""}>
              <strong>{criticalCount}</strong>
              <span>Critical</span>
            </div>
            <div>
              <strong>{summary.inProgressIssues.length}</strong>
              <span>In progress</span>
            </div>
          </div>
          <div className="overview-snapshot-footer">
            <span>
              {unassignedCount
                ? `${unassignedCount} unassigned`
                : "All active reports assigned"}
            </span>
            <button type="button" onClick={() => onNavigate("queue")}>
              Open queue <ChevronRight size={14} aria-hidden="true" />
            </button>
          </div>
        </aside>
      </section>
      <div className="kpi-grid">
        <Kpi
          icon={FileText}
          label="All reports"
          value={summary.totalCount}
          helper="In your work area"
          tone="teal"
        />
        <Kpi
          icon={Activity}
          label="Open reports"
          value={summary.activeCount}
          helper="Still need follow-up"
          tone="clay"
        />
        <Kpi
          icon={Wrench}
          label="Being worked on"
          value={summary.inProgressIssues.length}
          helper="Work is underway"
          tone="green"
        />
        <Kpi
          icon={CheckCircle2}
          label="Completed"
          value={summary.completedCount}
          helper="Marked as resolved"
          tone="amber"
        />
      </div>

      <div className="two-column">
        <MapCard issues={issues} onOpenIssue={onOpenIssue} user={user} />
        <LatestReportsCard
          issues={issues}
          onOpenIssue={onOpenIssue}
          onNavigate={onNavigate}
        />
      </div>

      <div className="two-column lower">
        <CategoryCard categories={overviewData?.categories ?? []} />
        <TeamCard teams={overviewData?.teams ?? []} />
      </div>
    </div>
  );
}

function Kpi({ icon, label, value, helper, tone }) {
  return (
    <article className={`kpi card dashboard-kpi ${tone}`}>
      <div className={`kpi-icon ${tone}`}>
        <Icon icon={icon} />
      </div>
      <p>{label}</p>
      <strong>{value}</strong>
      <small>{helper}</small>
    </article>
  );
}

function LatestReportsCard({ issues, onOpenIssue, onNavigate }) {
  const latestIssues = issues.slice(0, 4);

  return (
    <article className="card latest-reports-card">
      <div className="card-head">
        <div>
          <h2>Latest reports</h2>
          <p className="dashboard-card-hint">Newest reports first</p>
        </div>
        <button
          type="button"
          className="text-link"
          onClick={() => onNavigate("queue")}
        >
          View all reports <ChevronRight size={15} />
        </button>
      </div>
      {latestIssues.length ? (
        <div className="latest-reports-list">
          {latestIssues.map((issue) => (
            <button
              type="button"
              className="latest-report"
              key={issue.id}
              onClick={() => onOpenIssue(issue)}
              aria-label={`Open report: ${issue.title}`}
            >
              <span
                className={`latest-report-icon ${issue.severity?.toLowerCase() || "medium"}`}
              >
                <Flag size={16} />
              </span>
              <span className="latest-report-copy">
                <strong>{issue.title}</strong>
                <span>
                  {issue.status} · {issue.location}
                </span>
              </span>
              <ChevronRight size={16} className="latest-report-chevron" />
            </button>
          ))}
        </div>
      ) : (
        <div className="dashboard-empty-state">
          <CheckCircle2 size={21} />
          <strong>No reports yet</strong>
          <span>New reports will appear here.</span>
        </div>
      )}
    </article>
  );
}

function MapCard({ issues, onOpenIssue, user }) {
  const [filter, setFilter] = useState("all");

  const visibleIssues = useMemo(() => {
    if (filter === "all") return issues;
    return issues.filter((issue) => {
      if (filter === "unassigned") {
        const assignedTeam = String(
          issue.assigned_team || issue.assignedTeam || "",
        ).trim();
        return !assignedTeam || assignedTeam.toLowerCase() === "unassigned";
      }
      if (filter === "resolved") {
        return issue.status === "Resolved";
      }
      return issue.severity === filter || issue.status === filter;
    });
  }, [filter, issues]);

  const filterOptions = [
    { value: "all", label: "All", icon: Layers3 },
    { value: "Critical", label: "Critical", icon: ShieldAlert },
    { value: "High", label: "High", icon: TriangleAlert },
    { value: "Medium", label: "Medium", icon: CircleAlert },
    { value: "resolved", label: "Resolved", icon: CheckCircle2 },
    { value: "unassigned", label: "Unassigned", icon: UserRoundX },
  ];

  return (
    <article className="card map-card">
      <div className="card-head map-card-heading">
        <div>
          <h2>Report map</h2>
          <p className="dashboard-card-hint">
            Select a marker to see report details.
          </p>
        </div>
        <div className="filters" style={{ marginBottom: 0 }}>
          {filterOptions.map(({ value, label, icon: FilterIcon }) => (
            <button
              key={value}
              type="button"
              className={`filter map-overview-filter ${filter === value ? "active" : ""}`}
              aria-pressed={filter === value}
              onClick={() => setFilter(value)}
            >
              <FilterIcon size={13} strokeWidth={2} aria-hidden="true" />
              <span>{label}</span>
            </button>
          ))}
        </div>
      </div>
      <LeafletInfrastructureMap
        issues={visibleIssues}
        onOpenIssue={onOpenIssue}
        barangay={user?.barangay}
      />
    </article>
  );
}

function CategoryCard({ categories }) {
  const max = Math.max(...categories.map((item) => item.count), 1);
  return (
    <article className="card">
      <div className="card-head">
        <h2>Reports by category</h2>
        <span className="muted">All reports</span>
      </div>
      {categories.map((item, index) => (
        <div className="bar-row" key={item.name}>
          <span>{item.name}</span>
          <div className="bar">
            <i
              className={
                ["clay", "amber", "teal", "purple", "green"][index % 5]
              }
              style={{ width: `${(item.count / max) * 100}%` }}
            />
          </div>
          <b>{item.count}</b>
        </div>
      ))}
      {!categories.length && <p className="muted">No reports to group yet.</p>}
    </article>
  );
}

function TeamCard({ teams }) {
  return (
    <article className="card">
      <div className="card-head">
        <h2>Team workload</h2>
        <span className="muted">Open reports</span>
      </div>
      {teams.map((team) => (
        <div className="activity-item" key={team.name}>
          <div className="activity-icon assign">
            <Icon icon={team.name === "Unassigned" ? Flag : Wrench} />
          </div>
          <div>
            <b>{team.name}</b>
            <p>
              {team.activeCount} open{" "}
              {team.activeCount === 1 ? "report" : "reports"}
            </p>
          </div>
        </div>
      ))}
      {!teams.length && (
        <div className="dashboard-empty-state compact">
          <Users size={19} />
          <strong>No open assignments</strong>
          <span>Team workload will appear when reports are open.</span>
        </div>
      )}
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
    ["Barangay Dawan Hall", "Public building repairs", 38],
    ["Rizal Street", "Road surface damage", 27],
    ["Public Market area", "Drainage blockage", 21],
    ["J.P. Laurel Ave.", "Electric pole inspection", 14],
  ];

  const teamEfficiency = [
    ["Team Alpha", 92, "clay"],
    ["Crew Delta", 88, "amber"],
    ["Electrician U4", 95, "purple"],
    ["Public Facilities Unit", 79, "teal"],
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
            940 residents rated a completed repair this quarter. 82% gave 4–5
            stars, read as <b>positive</b> sentiment; 9% neutral; 9% negative —
            negative ratings are auto-flagged for a follow-up review.
          </p>
        </article>

        <article className="card analytics-panel">
          <div className="card-head">
            <h2>Resolution time trend</h2>
            <span className="muted">Weeks</span>
          </div>

          <svg
            className="trend-chart"
            viewBox="0 0 260 120"
            preserveAspectRatio="none"
            aria-label="Resolution trend chart"
          >
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
            <line
              x1="0"
              y1="105"
              x2="260"
              y2="105"
              stroke="var(--line)"
              strokeWidth="1"
            />
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
            Efficiency reflects on-time completion against assigned target
            dates, used for resource allocation planning.
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
            Printable summaries support recurring reporting to the City
            Engineering Office and CDRRMO for planning and budget review.
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
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let active = true;
    setIsLoading(true);
    setError("");
    apiFetch(
      `/analytics?period=${period}&userId=${encodeURIComponent(user?.id || "")}`,
    )
      .then(async (response) => {
        const body = await response.json();
        if (!response.ok)
          throw new Error(body.error || "Could not load analytics");
        if (active) setData(body);
      })
      .catch((loadError) => {
        if (active) setError(loadError.message);
      })
      .finally(() => {
        if (active) setIsLoading(false);
      });
    return () => {
      active = false;
    };
  }, [period, reloadKey, user?.id]);

  if (!data && isLoading)
    return <DashboardLoading message="Loading analytics…" />;

  const currentData = data?.period === period ? data : null;
  const reportTotal = Number(currentData?.summary.total) || 0;
  const categoryRows = getAnalyticsCategoryRows(
    currentData?.categories ?? [],
    reportTotal,
  );
  const maxCategory = Math.max(...categoryRows.map((item) => item.count), 1);
  const trendItems = currentData?.trend ?? [];
  const maxTrend = Math.max(...trendItems.map((item) => Number(item.count)), 1);
  const trendCoordinates = trendItems.map((item, index) => {
    const x =
      trendItems.length === 1
        ? 130
        : 10 + (index / (trendItems.length - 1)) * 240;
    const y = 88 - (Number(item.count) / maxTrend) * 58;
    return { x, y, count: Number(item.count) };
  });
  const trendPoints = trendCoordinates.map(({ x, y }) => `${x},${y}`).join(" ");
  const periodOptions = [
    { value: "day", label: "Last 24 hours" },
    { value: "week", label: "Last 7 days" },
    { value: "month", label: "Last 30 days" },
    { value: "year", label: "Last 12 months" },
  ];
  const widerPeriod = { day: "week", week: "month", month: "year" }[period];
  const periodEmptyMessage = error
    ? "Analytics could not be loaded."
    : isLoading
      ? "Updating analytics…"
      : "No reports were submitted in this period.";
  const isAnalyticsPanelEmpty = !currentData || reportTotal === 0;

  return (
    <>
      <div className="card analytics-period-bar">
        <div
          className="analytics-period-controls"
          role="group"
          aria-label="Report date range"
        >
          <strong>Reports from</strong>
          {periodOptions.map(({ value, label }) => (
            <button
              key={value}
              type="button"
              className={`filter ${period === value ? "active" : ""}`}
              aria-pressed={period === value}
              onClick={() => setPeriod(value)}
            >
              {label}
            </button>
          ))}
        </div>
        <span className="muted" role={isLoading ? "status" : undefined}>
          {isLoading
            ? "Updating reports…"
            : currentData?.periodLabel || "Analytics unavailable"}
        </span>
        <button
          type="button"
          className="primary-button print-button"
          onClick={() => window.print()}
        >
          Print / Save PDF
        </button>
      </div>
      {error && (
        <div className="analytics-error" role="alert">
          <span>Could not load analytics: {error}</span>
          <button
            type="button"
            className="text-link"
            onClick={() => setReloadKey((key) => key + 1)}
          >
            Try again
          </button>
        </div>
      )}
      {currentData && reportTotal === 0 && (
        <div className="analytics-empty-notice" role="status">
          <span>
            No reports were recorded in the last{" "}
            {currentData.periodLabel?.replace(/^Last /, "") ||
              "selected period"}
            .
          </span>
          {widerPeriod && (
            <button
              type="button"
              className="text-link"
              onClick={() => setPeriod(widerPeriod)}
            >
              View{" "}
              {periodOptions
                .find((option) => option.value === widerPeriod)
                ?.label.toLowerCase()}
            </button>
          )}
        </div>
      )}
      <div className="kpi-grid">
        <Kpi
          icon={FileText}
          label="Reports in period"
          value={currentData?.summary.total ?? "—"}
          helper="In selected date range"
          tone="teal"
        />
        <Kpi
          icon={AlertTriangle}
          label="Reported"
          value={currentData?.summary.reported ?? "—"}
          helper="Awaiting action"
          tone="clay"
        />
        <Kpi
          icon={Activity}
          label="In progress"
          value={currentData?.summary.inProgress ?? "—"}
          helper="Work underway"
          tone="green"
        />
        <Kpi
          icon={CheckCircle2}
          label="Resolved"
          value={currentData?.summary.resolved ?? "—"}
          helper="Completed reports"
          tone="amber"
        />
      </div>
      <div className="analytics-grid">
        <article
          className={`card analytics-panel ${isAnalyticsPanelEmpty ? "is-empty" : ""}`}
        >
          <div className="card-head">
            <h2>Reports by category</h2>
            <span className="muted">{reportTotal} reports</span>
          </div>
          {categoryRows.map((item, index) => (
            <div className="bar-row analytics-category-row" key={item.name}>
              <span>{item.name}</span>
              <div
                className="bar"
                role="img"
                aria-label={`${item.name}: ${item.count} reports`}
              >
                <i
                  className={
                    ["clay", "amber", "teal", "purple", "green"][index % 5]
                  }
                  style={{ width: `${(item.count / maxCategory) * 100}%` }}
                />
              </div>
              <b>{item.count}</b>
            </div>
          ))}
          {!categoryRows.length && (
            <p className="analytics-empty-copy">{periodEmptyMessage}</p>
          )}
          {!!currentData &&
            reportTotal > 0 &&
            categoryRows.some((item) => item.name === "Other categories") && (
              <p className="analytics-chart-note">
                Includes reports saved under older or unlisted category names.
              </p>
            )}
        </article>
        <article
          className={`card analytics-panel ${isAnalyticsPanelEmpty ? "is-empty" : ""}`}
        >
          <div className="card-head">
            <h2>Report trend</h2>
            <span className="muted">
              {currentData?.periodLabel || "Selected period"}
            </span>
          </div>
          {trendItems.length ? (
            <>
              <svg
                className="trend-chart"
                viewBox="0 0 260 105"
                preserveAspectRatio="none"
                role="img"
                aria-labelledby="analytics-trend-title analytics-trend-description"
              >
                <title id="analytics-trend-title">Reports over time</title>
                <desc id="analytics-trend-description">
                  {trendItems
                    .map((item) => `${item.label}: ${item.count} reports`)
                    .join(". ")}
                </desc>
                <line
                  x1="8"
                  y1="30"
                  x2="252"
                  y2="30"
                  className="trend-grid-line"
                />
                <line
                  x1="8"
                  y1="59"
                  x2="252"
                  y2="59"
                  className="trend-grid-line"
                />
                <line
                  x1="8"
                  y1="88"
                  x2="252"
                  y2="88"
                  className="trend-grid-line"
                />
                {trendPoints && (
                  <polyline
                    points={trendPoints}
                    fill="none"
                    stroke="var(--teal)"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                )}
                {trendCoordinates.map(({ x, y, count }, index) => (
                  <circle
                    key={`${trendItems[index].label}-${index}`}
                    cx={x}
                    cy={y}
                    r="3"
                    fill="var(--teal)"
                    aria-label={`${count} reports`}
                  />
                ))}
              </svg>
              <div className="trend-axis-labels" aria-hidden="true">
                <span>
                  {formatAnalyticsTrendLabel(trendItems[0].label, period)}
                </span>
                {trendItems.length > 1 && (
                  <span>
                    {formatAnalyticsTrendLabel(
                      trendItems[trendItems.length - 1].label,
                      period,
                    )}
                  </span>
                )}
              </div>
              <p className="trend-caption">
                {trendItems.length}{" "}
                {trendItems.length === 1
                  ? "reporting period"
                  : "reporting periods"}{" "}
                · {reportTotal} reports
              </p>
            </>
          ) : (
            <p className="analytics-empty-copy">
              {reportTotal > 0
                ? "No trend data is available for this period."
                : periodEmptyMessage}
            </p>
          )}
        </article>
        <article
          className={`card analytics-panel ${isAnalyticsPanelEmpty ? "is-empty" : ""}`}
        >
          <div className="card-head">
            <h2>Hotspots</h2>
            <span className="muted">Most reported locations</span>
          </div>
          {(currentData?.hotspots ?? []).map((item, index) => {
            const categories = String(item.categories ?? item.category ?? "")
              .split(",")
              .map((category) => category.trim())
              .filter(Boolean);
            const categorySummary =
              categories.length > 2
                ? `${categories.slice(0, 2).join(" · ")} +${categories.length - 2} more`
                : categories.join(" · ");

            return (
              <div className="hotspot" key={item.name}>
                <b>{String(index + 1).padStart(2, "0")}</b>
                <span>
                  <strong>{item.name}</strong>
                  {categorySummary && <small>{categorySummary}</small>}
                </span>
                <em>{item.count}</em>
              </div>
            );
          })}
          {!currentData?.hotspots?.length && (
            <p className="analytics-empty-copy">
              {reportTotal > 0
                ? "Location details are unavailable for these reports."
                : periodEmptyMessage}
            </p>
          )}
        </article>
      </div>
      <article
        className={`card analytics-panel resident-rating-panel ${!currentData || !Number(currentData.ratings?.total) ? "is-empty" : ""}`}
      >
        <div className="card-head">
          <h2>Resident ratings</h2>
          <span className="muted">Feedback received in this period</span>
        </div>
        {Number(currentData?.ratings?.total) > 0 ? (
          <>
            <div className="sentiment-gauge">
              <div
                className="sentiment-ring"
                style={{
                  "--rating-angle": `${Math.min(5, Math.max(0, Number(currentData.ratings.average) || 0)) * 72}deg`,
                }}
              >
                <strong>{currentData.ratings.average}</strong>
                <span>OUT OF 5</span>
              </div>
            </div>
            <p className="sentiment-note">
              Average from {currentData.ratings.total} resident{" "}
              {Number(currentData.ratings.total) === 1 ? "rating" : "ratings"}.
            </p>
          </>
        ) : (
          <div className="rating-empty-state">
            <Star size={20} aria-hidden="true" />
            <strong>No ratings yet</strong>
            <span>
              {currentData
                ? "No resident feedback was recorded for this period."
                : periodEmptyMessage}
            </span>
          </div>
        )}
      </article>
      <article
        className={`card analytics-panel thematic-analysis-panel ${isAnalyticsPanelEmpty ? "is-empty" : ""}`}
      >
        <div className="card-head">
          <h2>Thematic analysis</h2>
          <span className="muted">{reportTotal} reports analyzed</span>
        </div>
        <p className="thematic-analysis-note">
          Primary themes are identified from report categories, titles, and
          descriptions. Each report is counted once.
        </p>
        {(currentData?.themes ?? []).map((theme, index) => (
          <div className="thematic-row" key={theme.name}>
            <div className="thematic-row-heading">
              <strong>{theme.name}</strong>
              <span>
                {theme.count} · {theme.percentage}%
              </span>
            </div>
            <div
              className="thematic-track"
              aria-label={`${theme.name}: ${theme.count} reports, ${theme.percentage}%`}
            >
              <i
                className={
                  ["clay", "amber", "teal", "purple", "green"][index % 5]
                }
                style={{ width: `${theme.percentage}%` }}
              />
            </div>
            <small>{theme.description}</small>
          </div>
        ))}
        {!currentData?.themes?.length && (
          <p className="analytics-empty-copy">
            {reportTotal > 0
              ? "No report themes were identified for this period."
              : periodEmptyMessage}
          </p>
        )}
      </article>
    </>
  );
}
