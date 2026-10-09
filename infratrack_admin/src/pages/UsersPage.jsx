import { useEffect, useState } from "react";
import { Ban, CheckCircle2, Eye, Hourglass, ShieldCheck, UserPlus } from "lucide-react";
import { apiFetch } from "../api";

export default function UsersPage({ users, onOpenUser, user }) {
  const [staff, setStaff] = useState([]);
  const [showStaffForm, setShowStaffForm] = useState(false);
  const [staffError, setStaffError] = useState("");
  const [staffNotice, setStaffNotice] = useState("");
  const [staffForm, setStaffForm] = useState({ name: "", email: "", barangay: "", password: "Mati2026!", role: "barangay_staff" });
  const [passwordModal, setPasswordModal] = useState({ open: false, account: null, value: "", confirm: "", error: "" });
  const canManageStaff = ["lgu", "admin"].includes(user?.role);

  const loadStaff = () => apiFetch("/staff").then(async (response) => {
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "Could not load staff accounts");
    setStaff(data.staff ?? []);
  }).catch((error) => setStaffError(error.message));

  useEffect(() => {
    if (canManageStaff) loadStaff();
  }, [canManageStaff]);

  const createStaff = async (event) => {
    event.preventDefault();
    setStaffError("");
    try {
      const response = await apiFetch("/staff", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(staffForm) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Could not create staff account");
      setStaffForm({ name: "", email: "", barangay: "", password: "Mati2026!", role: "barangay_staff" });
      setShowStaffForm(false);
      setStaffNotice(data.emailNotification?.sent
        ? `Staff account created. An account email was sent to ${data.staff.email}.`
        : data.emailNotification?.configured
          ? "Staff account created, but its email could not be sent. Please check the server configuration."
          : "Staff account created. Email notifications are not configured yet.");
      loadStaff();
    } catch (error) { setStaffError(error.message); }
  };

  const toggleStaff = async (account) => {
    const standing = account.standing === "Disabled" ? "Active" : "Disabled";
    const response = await apiFetch(`/staff/${account.id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ standing }) });
    const data = await response.json();
    if (!response.ok) setStaffError(data.error || "Could not update staff account");
    else loadStaff();
  };

  const resetStaffPassword = async (account) => {
    setPasswordModal({ open: true, account, value: "", confirm: "", error: "" });
  };

  const submitPasswordReset = async () => {
    const trimmed = passwordModal.value.trim();
    const confirmed = passwordModal.confirm.trim();
    const account = passwordModal.account;
    if (!account) return;
    if (!trimmed || trimmed.length < 8) {
      setPasswordModal((current) => ({ ...current, error: "Password must be at least 8 characters" }));
      return;
    }
    if (trimmed !== confirmed) {
      setPasswordModal((current) => ({ ...current, error: "Passwords do not match" }));
      return;
    }

    try {
      const response = await apiFetch(`/staff/${account.id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ password: trimmed }) });
      const data = await response.json();
      if (!response.ok) {
        setPasswordModal((current) => ({ ...current, error: data.error || "Could not reset password" }));
        return;
      }

      setPasswordModal({ open: false, account: null, value: "", confirm: "", error: "" });
      setStaffError("");
      setStaffNotice(data.emailNotification?.sent
        ? `Password reset. A security alert was emailed to ${account.email}.`
        : data.emailNotification?.configured
          ? "Password reset, but the security email could not be sent. Please check the server configuration."
          : "Password reset. Email alerts are not configured yet.");
      loadStaff();
    } catch (error) {
      setPasswordModal((current) => ({ ...current, error: error.message || "Could not reset password" }));
    }
  };

  return (
    <div className="users-page-stack">
      {canManageStaff && <section className="card staff-management-card">
        <div className="staff-management-header">
          <div><h2>Staff accounts</h2><p>Create and manage LGU and barangay staff access.</p></div>
          <button type="button" className="primary-button staff-add-button" onClick={() => setShowStaffForm((current) => !current)}><UserPlus size={16} /> {showStaffForm ? "Close" : "Add staff"}</button>
        </div>
        {passwordModal.open && (
          <div className="staff-password-backdrop" onClick={() => setPasswordModal({ open: false, account: null, value: "", confirm: "", error: "" })}>
            <div className="staff-password-modal" onClick={(event) => event.stopPropagation()}>
              <div className="staff-password-header">
                <div>
                  <span className="staff-password-eyebrow">Security</span>
                  <h3>Reset password</h3>
                </div>
                <button type="button" className="staff-password-close" aria-label="Close password reset" onClick={() => setPasswordModal({ open: false, account: null, value: "", confirm: "", error: "" })}>×</button>
              </div>
              <label className="staff-password-label" htmlFor="staff-password-reset">New password for {passwordModal.account?.name}</label>
              <div className="staff-password-fields">
                <input id="staff-password-reset" className={`settings-input ${passwordModal.error ? "input-error" : ""}`} type="password" value={passwordModal.value} onChange={(event) => setPasswordModal((current) => ({ ...current, value: event.target.value, error: "" }))} placeholder="Enter new password (8+ characters)" autoFocus />
                <input className={`settings-input ${passwordModal.error ? "input-error" : ""}`} type="password" value={passwordModal.confirm} onChange={(event) => setPasswordModal((current) => ({ ...current, confirm: event.target.value, error: "" }))} placeholder="Confirm password" />
                {passwordModal.error && <p role="alert" className="staff-password-error">{passwordModal.error}</p>}
              </div>
              <div className="staff-password-actions">
                <button type="button" className="secondary-button" onClick={() => setPasswordModal({ open: false, account: null, value: "", confirm: "", error: "" })}>Cancel</button>
                <button type="button" className="primary-button" onClick={submitPasswordReset}>Save password</button>
              </div>
            </div>
          </div>
        )}
        {showStaffForm && <form className="staff-form" onSubmit={createStaff}>
          <div className="staff-form-heading">
            <span className="staff-form-icon"><UserPlus size={19} /></span>
            <div>
              <h3>Create a staff account</h3>
              <p>Add a team member and assign their access.</p>
            </div>
            <span className="staff-required-note">All fields required</span>
          </div>
          <div className="staff-form-section">
            <h4>Staff details</h4>
            <div className="staff-form-fields">
              <label className="staff-form-field" htmlFor="staff-name">
                <span>Full name</span>
                <input id="staff-name" autoComplete="name" placeholder="e.g. Maria Santos" value={staffForm.name} onChange={(event) => setStaffForm({ ...staffForm, name: event.target.value })} required />
              </label>
              <label className="staff-form-field" htmlFor="staff-email">
                <span>Work email</span>
                <input id="staff-email" type="email" autoComplete="email" placeholder="name@mati.gov.ph" value={staffForm.email} onChange={(event) => setStaffForm({ ...staffForm, email: event.target.value })} required />
              </label>
              <label className="staff-form-field" htmlFor="staff-barangay">
                <span>Assigned barangay</span>
                <input id="staff-barangay" autoComplete="address-level3" placeholder="e.g. Central" value={staffForm.barangay} onChange={(event) => setStaffForm({ ...staffForm, barangay: event.target.value })} required />
              </label>
            </div>
          </div>
          <div className="staff-form-section">
            <h4>Account access</h4>
            <div className="staff-form-fields">
              <label className="staff-form-field" htmlFor="staff-role">
                <span>Staff role</span>
                <select id="staff-role" value={staffForm.role} onChange={(event) => setStaffForm({ ...staffForm, role: event.target.value })}>
                  <option value="barangay_staff">Barangay staff</option>
                  <option value="lgu">LGU administrator</option>
                </select>
              </label>
              <label className="staff-form-field" htmlFor="staff-password">
                <span>Temporary password</span>
                <input id="staff-password" type="password" autoComplete="new-password" minLength={8} placeholder="At least 8 characters" value={staffForm.password} onChange={(event) => setStaffForm({ ...staffForm, password: event.target.value })} required />
                <small>They can change this after signing in.</small>
              </label>
            </div>
          </div>
          <div className="staff-form-actions">
            <button type="button" className="secondary-button" onClick={() => setShowStaffForm(false)}>Cancel</button>
            <button type="submit" className="primary-button"><UserPlus size={15} /> Create account</button>
          </div>
        </form>}
        {staffError && <p role="alert" className="staff-error">{staffError}</p>}
        {staffNotice && <p role="status" className={`staff-notice ${staffNotice.includes("could not be sent") ? "staff-notice-warning" : ""}`}>{staffNotice}</p>}
        <div className="staff-account-list">{staff.map((account) => <div className="staff-account-row" key={account.id}><div><strong>{account.name}</strong><small>{account.email} · {account.barangay} · {account.role}</small></div><div className="staff-action-group"><span className={`status ${account.standing === "Active" ? "resolved" : "pending"}`}>{account.standing}</span><button type="button" className="view-user-button" onClick={() => resetStaffPassword(account)}>Reset password</button><button type="button" className="view-user-button" onClick={() => toggleStaff(account)}>{account.standing === "Disabled" ? "Activate" : "Disable"}</button></div></div>)}</div>
      </section>}
      <div className="card table-card">
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
              <th />
            </tr>
          </thead>
          <tbody>
            {users.map(({ id, name, email, barangay, reports, standing, verification, joined }) => (
              <tr key={email} onClick={() => onOpenUser({ id, name, email, barangay, reports, standing, joined })}>
                <td>
                  <div className="issue-title">
                    <span className="user-avatar" title={name}>
                      {name
                        .split(" ")
                        .map((part) => part[0])
                        .join("")
                        .slice(0, 2)}
                    </span>
                    <span>
                      <b>{name}</b>
                      <small>{email}</small>
                    </span>
                  </div>
                </td>
                <td>{barangay}</td>
                <td>{reports}</td>
                <td>
                  <span className={`status ${standing.toLowerCase()}`}>
                    <span className="badge-icon">
                      {standing === "Active" ? <CheckCircle2 size={11} /> : <Ban size={11} />}
                    </span>
                    {standing}
                  </span>
                </td>
                <td>
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
                <td>{joined}</td>
                <td>
                  <button
                    className="view-user-button"
                    onClick={(event) => {
                      event.stopPropagation();
                      onOpenUser({ id, name, email, barangay, reports, standing, joined });
                    }}
                  >
                    <Eye size={16} strokeWidth={2.2} /> View
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      </div>
    </div>
  );
}
