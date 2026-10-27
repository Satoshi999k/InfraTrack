import { createPortal } from "react-dom";
import { useEffect, useRef, useState } from "react";
import {
  Ban,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Eye,
  EyeOff,
  Hourglass,
  Search,
  ShieldCheck,
  UserPlus,
  X,
} from "lucide-react";
import { apiFetch } from "../api";
import { filterResidents, paginateResidents } from "../../residentSearch.js";

const createStaffForm = () => ({
  name: "",
  email: "",
  mobile: "",
  barangay: "",
  password: "",
  role: "barangay_staff",
});

export default function UsersPage({ users, onOpenUser, user }) {
  const passwordDialogRef = useRef(null);
  const staffDialogRef = useRef(null);
  const isCreatingStaffRef = useRef(false);
  const [isCreatingStaff, setIsCreatingStaff] = useState(false);
  const [isSavingPassword, setIsSavingPassword] = useState(false);
  const [showResetPassword, setShowResetPassword] = useState(false);
  const [residentPage, setResidentPage] = useState(1);
  const [residentSearch, setResidentSearch] = useState("");
  const [staff, setStaff] = useState([]);
  const [showStaffForm, setShowStaffForm] = useState(false);
  const [staffError, setStaffError] = useState("");
  const [createStaffError, setCreateStaffError] = useState("");
  const [staffNotice, setStaffNotice] = useState("");
  const [staffForm, setStaffForm] = useState(createStaffForm);
  const [passwordModal, setPasswordModal] = useState({
    open: false,
    account: null,
    value: "",
    confirm: "",
    error: "",
  });
  const canManageStaff = ["lgu", "admin"].includes(user?.role);
  const visibleResidents = filterResidents(users, residentSearch);
  const residentPageData = paginateResidents(visibleResidents, residentPage);
  isCreatingStaffRef.current = isCreatingStaff;

  const closeStaffForm = () => {
    if (isCreatingStaffRef.current) return;
    setShowStaffForm(false);
    setStaffForm(createStaffForm());
    setCreateStaffError("");
  };

  useEffect(() => {
    if (!showStaffForm) return undefined;

    const previousFocus = document.activeElement;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    staffDialogRef.current?.querySelector("#staff-name")?.focus();

    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        closeStaffForm();
        return;
      }

      if (event.key !== "Tab") return;
      const currentFocusable = staffDialogRef.current?.querySelectorAll(
        'button:not(:disabled), input:not(:disabled), select:not(:disabled)',
      );
      if (!currentFocusable?.length) {
        event.preventDefault();
        staffDialogRef.current?.focus();
        return;
      }
      const first = currentFocusable[0];
      const last = currentFocusable[currentFocusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
      if (previousFocus instanceof HTMLElement) previousFocus.focus();
    };
  }, [showStaffForm]);

  useEffect(() => {
    if (!passwordModal.open) return undefined;

    const previousFocus = document.activeElement;
    const focusable = passwordDialogRef.current?.querySelectorAll(
      'button:not(:disabled), input:not(:disabled)',
    );
    focusable?.[0]?.focus();

    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setPasswordModal({
          open: false,
          account: null,
          value: "",
          confirm: "",
          error: "",
        });
        return;
      }

      if (event.key !== "Tab" || !focusable?.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      if (previousFocus instanceof HTMLElement) previousFocus.focus();
    };
  }, [passwordModal.open]);

  const loadStaff = () =>
    apiFetch("/staff")
      .then(async (response) => {
        const data = await response.json();
        if (!response.ok)
          throw new Error(data.error || "Could not load staff accounts");
        setStaff(data.staff ?? []);
      })
      .catch((error) => setStaffError(error.message));

  useEffect(() => {
    if (canManageStaff) loadStaff();
  }, [canManageStaff]);

  const createStaff = async (event) => {
    event.preventDefault();
    setCreateStaffError("");
    setIsCreatingStaff(true);
    try {
      const response = await apiFetch("/staff", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(staffForm),
      });
      const data = await response.json();
      if (!response.ok)
        throw new Error(data.error || "Could not create staff account");
      setStaffForm(createStaffForm());
      setShowStaffForm(false);
      setStaffNotice(
        data.emailNotification?.sent
          ? `Staff account created. An account email was sent to ${data.staff.email}.`
          : data.emailNotification?.configured
            ? "Staff account created, but its email could not be sent. Please check the server configuration."
            : "Staff account created. Email notifications are not configured yet.",
      );
      loadStaff();
    } catch (error) {
      setCreateStaffError(error.message);
    } finally {
      setIsCreatingStaff(false);
    }
  };

  const toggleStaff = async (account) => {
    const standing = account.standing === "Disabled" ? "Active" : "Disabled";
    const response = await apiFetch(`/staff/${account.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ standing }),
    });
    const data = await response.json();
    if (!response.ok)
      setStaffError(data.error || "Could not update staff account");
    else loadStaff();
  };

  const resetStaffPassword = async (account) => {
    setShowResetPassword(false);
    setPasswordModal({
      open: true,
      account,
      value: "",
      confirm: "",
      error: "",
    });
  };

  const submitPasswordReset = async () => {
    const trimmed = passwordModal.value.trim();
    const confirmed = passwordModal.confirm.trim();
    const account = passwordModal.account;
    if (!account) return;
    if (!trimmed || trimmed.length < 8) {
      setPasswordModal((current) => ({
        ...current,
        error: "Password must be at least 8 characters",
      }));
      return;
    }
    if (trimmed !== confirmed) {
      setPasswordModal((current) => ({
        ...current,
        error: "Passwords do not match",
      }));
      return;
    }

    setIsSavingPassword(true);
    try {
      const response = await apiFetch(`/staff/${account.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password: trimmed }),
      });
      const data = await response.json();
      if (!response.ok) {
        setPasswordModal((current) => ({
          ...current,
          error: data.error || "Could not reset password",
        }));
        return;
      }

      setPasswordModal({
        open: false,
        account: null,
        value: "",
        confirm: "",
        error: "",
      });
      setStaffError("");
      setStaffNotice(
        data.emailNotification?.sent
          ? `Password reset. A security alert was emailed to ${account.email}.`
          : data.emailNotification?.configured
            ? "Password reset, but the security email could not be sent. Please check the server configuration."
            : "Password reset. Email alerts are not configured yet.",
      );
      loadStaff();
    } catch (error) {
      setPasswordModal((current) => ({
        ...current,
        error: error.message || "Could not reset password",
      }));
    } finally {
      setIsSavingPassword(false);
    }
  };

  const closePasswordModal = () => {
    setPasswordModal({
      open: false,
      account: null,
      value: "",
      confirm: "",
      error: "",
    });
    setShowResetPassword(false);
  };

  return (
    <div className="users-page-stack">
      {canManageStaff && (
        <section className="card staff-management-card">
          <div className="staff-management-header">
            <div>
              <span className="users-section-eyebrow">Administration</span>
              <h2>Staff accounts</h2>
              <p>Create and manage LGU and barangay staff access.</p>
            </div>
            <button
              type="button"
              className="primary-button staff-add-button"
              disabled={isCreatingStaff}
              aria-expanded={showStaffForm}
              aria-controls="create-staff-form"
              onClick={() => {
                setStaffError("");
                setCreateStaffError("");
                setStaffForm(createStaffForm());
                setShowStaffForm(true);
              }}
            >
              <UserPlus size={16} /> Add staff
            </button>
          </div>
          <div className="staff-summary" aria-label="Staff account totals">
            <span>
              <strong>{staff.length}</strong>{" "}
              {staff.length === 1 ? "staff account" : "staff accounts"}
            </span>
            <span>
              <strong>
                {
                  staff.filter((account) => account.standing === "Active")
                    .length
                }
              </strong>{" "}
              active
            </span>
          </div>
          {passwordModal.open &&
            createPortal(
              <div
                className="staff-password-backdrop"
                onMouseDown={(event) => {
                  if (event.target === event.currentTarget) closePasswordModal();
                }}
              >
                <div
                  className="staff-password-modal"
                  ref={passwordDialogRef}
                  role="dialog"
                  aria-modal="true"
                  aria-labelledby="staff-password-title"
                  aria-describedby="staff-password-description"
                  tabIndex={-1}
                  onClick={(event) => event.stopPropagation()}
                >
                  <div className="staff-password-header">
                    <div>
                      <span className="staff-password-eyebrow">Security</span>
                      <h3 id="staff-password-title">Reset password</h3>
                      <p id="staff-password-description">
                        Set a new sign-in password for {passwordModal.account?.name}.
                      </p>
                    </div>
                    <button
                      type="button"
                      className="staff-password-close"
                      aria-label="Close password reset"
                      onClick={closePasswordModal}
                    >
                      <X size={17} aria-hidden="true" />
                    </button>
                  </div>
                  <form
                    onSubmit={(event) => {
                      event.preventDefault();
                      submitPasswordReset();
                    }}
                  >
                    <div className="staff-password-fields">
                    <div className="staff-password-field">
                      <label htmlFor="staff-password-reset">New password</label>
                      <div className="staff-password-input-wrap">
                        <input
                          id="staff-password-reset"
                          className={`settings-input ${passwordModal.error ? "input-error" : ""}`}
                          type={showResetPassword ? "text" : "password"}
                          autoComplete="new-password"
                          minLength={8}
                          value={passwordModal.value}
                          onChange={(event) =>
                            setPasswordModal((current) => ({
                              ...current,
                              value: event.target.value,
                              error: "",
                            }))
                          }
                          placeholder="At least 8 characters"
                          required
                          disabled={isSavingPassword}
                        />
                        <button
                          type="button"
                          className="staff-password-visibility"
                          aria-label={showResetPassword ? "Hide password" : "Show password"}
                          aria-pressed={showResetPassword}
                          onClick={() => setShowResetPassword((visible) => !visible)}
                        >
                          {showResetPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                        </button>
                      </div>
                      <small>Use at least 8 characters.</small>
                    </div>
                    <div className="staff-password-field">
                      <label htmlFor="staff-password-confirm">Confirm new password</label>
                      <input
                        id="staff-password-confirm"
                        className={`settings-input ${passwordModal.error ? "input-error" : ""}`}
                        type={showResetPassword ? "text" : "password"}
                        autoComplete="new-password"
                        value={passwordModal.confirm}
                        onChange={(event) =>
                          setPasswordModal((current) => ({
                            ...current,
                            confirm: event.target.value,
                            error: "",
                          }))
                        }
                        placeholder="Re-enter new password"
                        required
                        disabled={isSavingPassword}
                      />
                    </div>
                    {passwordModal.error && (
                      <p role="alert" className="staff-password-error">
                        {passwordModal.error}
                      </p>
                    )}
                  </div>
                  <div className="staff-password-actions">
                    <button
                      type="button"
                      className="secondary-button"
                      onClick={closePasswordModal}
                      disabled={isSavingPassword}
                    >
                      Cancel
                    </button>
                    <button type="submit" className="primary-button" disabled={isSavingPassword}>
                      {isSavingPassword ? "Saving..." : "Save password"}
                    </button>
                  </div>
                  </form>
                </div>
              </div>,
              document.body,
            )}
          {showStaffForm &&
            createPortal(
              <div
                className="staff-form-backdrop"
                onMouseDown={(event) => {
                  if (event.target === event.currentTarget) closeStaffForm();
                }}
              >
            <form
              ref={staffDialogRef}
              id="create-staff-form"
              className="staff-form"
              role="dialog"
              aria-modal="true"
              aria-labelledby="staff-form-title"
              aria-describedby="staff-form-description"
              aria-busy={isCreatingStaff}
              tabIndex={-1}
              onSubmit={createStaff}
            >
              <button
                type="button"
                className="staff-form-close"
                aria-label="Close create staff account"
                onClick={closeStaffForm}
                disabled={isCreatingStaff}
              >
                <X size={18} aria-hidden="true" />
              </button>
              <div className="staff-form-heading">
                <span className="staff-form-icon">
                  <UserPlus size={19} />
                </span>
                <div>
                  <span className="staff-form-eyebrow">Administration</span>
                  <h3 id="staff-form-title">Create staff account</h3>
                  <p id="staff-form-description">
                    Add a staff member and set their role and service area.
                  </p>
                </div>
                <span className="staff-required-note">Required fields <span aria-hidden="true">*</span></span>
              </div>
              {createStaffError && (
                <p className="staff-form-error" role="alert">{createStaffError}</p>
              )}
              <div className="staff-form-section staff-details-section">
                <h4><span>01</span> Staff details</h4>
                <div className="staff-form-fields">
                  <label className="staff-form-field" htmlFor="staff-name">
                    <span>Full name</span>
                    <input
                      id="staff-name"
                      autoComplete="name"
                      placeholder="e.g. Maria Santos"
                      value={staffForm.name}
                      onChange={(event) =>
                        setStaffForm({ ...staffForm, name: event.target.value })
                      }
                      required
                      disabled={isCreatingStaff}
                    />
                  </label>
                  <label className="staff-form-field" htmlFor="staff-email">
                    <span>Work email</span>
                    <input
                      id="staff-email"
                      type="email"
                      autoComplete="email"
                      placeholder="name@mati.gov.ph"
                      value={staffForm.email}
                      onChange={(event) =>
                        setStaffForm({
                          ...staffForm,
                          email: event.target.value,
                        })
                      }
                      required
                      disabled={isCreatingStaff}
                    />
                  </label>
                  <label className="staff-form-field" htmlFor="staff-mobile">
                    <span>Mobile number</span>
                    <input
                      id="staff-mobile"
                      type="tel"
                      inputMode="numeric"
                      autoComplete="tel"
                      placeholder="09XXXXXXXXX"
                      value={staffForm.mobile}
                      onChange={(event) =>
                        setStaffForm({
                          ...staffForm,
                          mobile: event.target.value.replace(/\D/g, "").slice(0, 11),
                        })
                      }
                      pattern="[0-9]{11}"
                      maxLength={11}
                      required
                      disabled={isCreatingStaff}
                    />
                    <small>Enter exactly 11 digits.</small>
                  </label>
                  <label className="staff-form-field" htmlFor="staff-barangay">
                    <span>
                      {staffForm.role === "lgu" ? "Service area" : "Assigned barangay"}
                    </span>
                    <input
                      id="staff-barangay"
                      autoComplete="address-level3"
                      placeholder={staffForm.role === "lgu" ? "e.g. Mati City" : "e.g. Central"}
                      value={staffForm.barangay}
                      onChange={(event) =>
                        setStaffForm({
                          ...staffForm,
                          barangay: event.target.value,
                        })
                      }
                      required
                      disabled={isCreatingStaff}
                    />
                  </label>
                </div>
              </div>
              <div className="staff-form-section">
                <h4><span>02</span> Account access</h4>
                <div className="staff-form-fields">
                  <label className="staff-form-field" htmlFor="staff-role">
                    <span>Staff role</span>
                    <select
                      id="staff-role"
                      value={staffForm.role}
                      onChange={(event) =>
                        setStaffForm({ ...staffForm, role: event.target.value })
                      }
                      disabled={isCreatingStaff}
                    >
                      <option value="barangay_staff">Barangay staff</option>
                      <option value="lgu">LGU administrator</option>
                    </select>
                  </label>
                  <label className="staff-form-field" htmlFor="staff-password">
                    <span>Temporary password</span>
                    <input
                      id="staff-password"
                      type="password"
                      autoComplete="new-password"
                      minLength={8}
                      placeholder="At least 8 characters"
                      value={staffForm.password}
                      onChange={(event) =>
                        setStaffForm({
                          ...staffForm,
                          password: event.target.value,
                        })
                      }
                      required
                      disabled={isCreatingStaff}
                    />
                    <small>Share this securely. They can change it after signing in.</small>
                  </label>
                </div>
              </div>
              <div className="staff-form-actions">
                <button
                  type="button"
                  className="secondary-button"
                  disabled={isCreatingStaff}
                  onClick={closeStaffForm}
                >
                  Cancel
                </button>
                <button type="submit" className="primary-button" disabled={isCreatingStaff}>
                  <UserPlus size={15} /> {isCreatingStaff ? "Creating account..." : "Create account"}
                </button>
              </div>
            </form>
              </div>,
              document.body,
            )}
          {staffError && (
            <p role="alert" className="staff-error">
              {staffError}
            </p>
          )}
          {staffNotice && (
            <p
              role="status"
              className={`staff-notice ${staffNotice.includes("could not be sent") ? "staff-notice-warning" : ""}`}
            >
              {staffNotice}
            </p>
          )}
          <div className="staff-account-list">
            {staff.map((account) => (
              <div className="staff-account-row" key={account.id}>
                <div className="staff-account-identity">
                  <span className="staff-account-avatar" aria-hidden="true">
                    {account.name
                      .trim()
                      .split(/\s+/)
                      .slice(0, 2)
                      .map((part) => part[0])
                      .join("")
                      .toUpperCase()}
                  </span>
                  <div className="staff-account-details">
                    <strong>{account.name}</strong>
                    <div className="staff-account-meta">
                      <small>{account.email}</small>
                      <span className="staff-account-scope">
                        {account.role === "lgu"
                          ? "LGU administrator"
                          : "Barangay staff"}{" "}
                        <span aria-hidden="true">·</span> {account.barangay}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="staff-action-group">
                  <span
                    className={`status ${account.standing === "Active" ? "resolved" : "pending"}`}
                    aria-label={`Account status: ${account.standing}`}
                  >
                    {account.standing}
                  </span>
                  <button
                    type="button"
                    className="view-user-button"
                    aria-label={`Reset password for ${account.name}`}
                    onClick={() => resetStaffPassword(account)}
                  >
                    Reset password
                  </button>
                  <button
                    type="button"
                    className={`view-user-button ${account.standing === "Disabled" ? "staff-enable-button" : "staff-disable-button"}`}
                    aria-label={`${account.standing === "Disabled" ? "Activate" : "Disable"} ${account.name}'s account`}
                    onClick={() => toggleStaff(account)}
                  >
                    {account.standing === "Disabled" ? "Activate" : "Disable"}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
      <div className="card table-card residents-table-card">
        <div className="residents-section-heading">
          <div>
            <span className="users-section-eyebrow">Community</span>
            <h2>Resident accounts</h2>
            <p>Review resident activity and verification status.</p>
          </div>
          <span className="residents-total-count">
            {users.length} {users.length === 1 ? "resident" : "residents"}
          </span>
        </div>
        <div className="residents-search-toolbar">
          <label className="residents-search-field">
            <Search size={17} aria-hidden="true" />
            <input
              type="search"
              aria-label="Search residents"
              placeholder="Search residents by name, email, or barangay"
              value={residentSearch}
              onChange={(event) => {
                setResidentSearch(event.target.value);
                setResidentPage(1);
              }}
            />
            {residentSearch && (
              <button
                type="button"
                className="residents-search-clear"
                aria-label="Clear resident search"
                onClick={() => {
                  setResidentSearch("");
                  setResidentPage(1);
                }}
              >
                <X size={16} />
              </button>
            )}
          </label>
          <span className="residents-search-count">
            {residentSearch.trim()
              ? `${visibleResidents.length} matching ${visibleResidents.length === 1 ? "resident" : "residents"}`
              : `${users.length} ${users.length === 1 ? "resident" : "residents"}`}
          </span>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Resident</th>
                <th>Barangay</th>
                <th>Reports</th>
                <th>Status</th>
                <th>Verification</th>
                <th>Joined</th>
                <th>
                  <span className="visually-hidden">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {residentPageData.total === 0 ? (
                <tr>
                  <td colSpan={7} className="residents-empty-result">
                    {residentSearch.trim()
                      ? "No residents match your search."
                      : "No residents to display."}
                  </td>
                </tr>
              ) : (
                residentPageData.items.map((resident) => {
                  const {
                    id,
                    name,
                    email,
                    barangay,
                    reports,
                    standing,
                    verification,
                    joined,
                  } = resident;
                  return (
                    <tr key={email} onClick={() => onOpenUser(resident)}>
                      <td data-label="Resident">
                        <div className="issue-title">
                          <span className="user-avatar" title={name}>
                            {name
                              .split(" ")
                              .map((part) => part[0])
                              .join("")
                              .slice(0, 2)}
                          </span>
                          <span>
                            <button
                              type="button"
                              className="resident-row-open"
                              aria-label={`View resident account for ${name}`}
                              onClick={(event) => {
                                event.stopPropagation();
                                onOpenUser(resident);
                              }}
                            >
                              {name}
                            </button>
                            <small>{email}</small>
                          </span>
                        </div>
                      </td>
                      <td data-label="Barangay">{barangay}</td>
                      <td data-label="Reports">{reports}</td>
                      <td data-label="Account status">
                        <span className={`status ${standing.toLowerCase()}`}>
                          <span className="badge-icon">
                            {standing === "Active" ? (
                              <CheckCircle2 size={11} />
                            ) : (
                              <Ban size={11} />
                            )}
                          </span>
                          {standing}
                        </span>
                      </td>
                      <td data-label="Verification">
                        <span
                          className={`status ${verification === "Verified" ? "verified" : verification === "Pending ID match" ? "pending" : "flagged"}`}
                        >
                          <span className="badge-icon">
                            {verification === "Verified" ? (
                              <ShieldCheck size={11} />
                            ) : verification === "Pending ID match" ? (
                              <Hourglass size={11} />
                            ) : (
                              <Ban size={11} />
                            )}
                          </span>
                          {verification}
                        </span>
                      </td>
                      <td data-label="Joined">{joined}</td>
                      <td data-label="Actions">
                        <button
                          className="view-user-button"
                          onClick={(event) => {
                            event.stopPropagation();
                            onOpenUser(resident);
                          }}
                        >
                          <Eye size={16} strokeWidth={2.2} /> View
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        <div className="residents-pagination">
          <span className="residents-pagination-range">
            {residentPageData.total === 0
              ? "No residents found"
              : `Showing ${residentPageData.start}–${residentPageData.end} of ${residentPageData.total} residents`}
          </span>
          {residentPageData.total > 0 && (
            <nav
              className="residents-pagination-controls"
              aria-label="Resident pages"
            >
              <button
                type="button"
                className="residents-pagination-button"
                aria-label="Previous residents page"
                disabled={residentPageData.page === 1}
                onClick={() =>
                  setResidentPage(Math.max(1, residentPageData.page - 1))
                }
              >
                <ChevronLeft size={14} aria-hidden="true" />
              </button>
              <span
                className="residents-pagination-label"
                aria-live="polite"
                aria-current="page"
              >
                Page {residentPageData.page} of {residentPageData.pageCount}
              </span>
              <button
                type="button"
                className="residents-pagination-button"
                aria-label="Next residents page"
                disabled={residentPageData.page === residentPageData.pageCount}
                onClick={() =>
                  setResidentPage(
                    Math.min(
                      residentPageData.pageCount,
                      residentPageData.page + 1,
                    ),
                  )
                }
              >
                <ChevronRight size={14} aria-hidden="true" />
              </button>
            </nav>
          )}
        </div>
      </div>
    </div>
  );
}
