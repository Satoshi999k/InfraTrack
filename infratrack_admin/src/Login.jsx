import { useEffect, useState } from "react";
import {
  ArrowRight,
  Building2,
  Eye,
  EyeOff,
  Landmark,
  LockKeyhole,
  Mail,
  ShieldCheck,
  UsersRound,
} from "lucide-react";
import matiAerial from "./assets/images/mati_aerial.jpg";
import { API_BASE } from "./api";
import { getRememberedEmail, saveAuthSession } from "./authSession";

const RECAPTCHA_SITE_KEY = import.meta.env.VITE_RECAPTCHA_SITE_KEY || "";

function getRecaptchaToken() {
  if (!RECAPTCHA_SITE_KEY) {
    return Promise.reject(new Error("Security verification is not configured on this site. Please contact the administrator."));
  }
  return new Promise((resolve, reject) => {
    const execute = () => window.grecaptcha.ready(() => window.grecaptcha.execute(RECAPTCHA_SITE_KEY, { action: "admin_login" }).then(resolve).catch(reject));
    if (window.grecaptcha) return execute();
    const script = document.createElement("script");
    script.src = "https://www.google.com/recaptcha/api.js?render=" + encodeURIComponent(RECAPTCHA_SITE_KEY);
    script.async = true;
    script.onload = execute;
    script.onerror = () => reject(new Error("Security verification could not load."));
    document.head.appendChild(script);
  });
}

export default function Login({ onLogin }) {
  const [email, setEmail] = useState(() => getRememberedEmail());
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(() => {
    if (!globalThis.localStorage) return false;
    return globalThis.localStorage.getItem("infratrack.adminRememberMe") === "true";
  });
  const [error, setError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: "auto" });
  }, []);

  const submit = async (event) => {
    event.preventDefault();
    if (!email.trim() || !password) {
      setError("Enter your email and password to continue.");
      return;
    }
    setError("");
    setIsSubmitting(true);
    try {
      const recaptchaToken = await getRecaptchaToken();
      const response = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, recaptchaToken }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "invalid credentials");
      if (!["lgu", "admin", "barangay_staff"].includes(data.user?.role)) {
        setError("This account is a resident account. Please use the InfraTrack mobile app.");
        return;
      }
      saveAuthSession({ token: data.token, user: data.user, rememberMe, email });
      onLogin(data.user);
    } catch (loginError) {
      setError(loginError.message || "We couldn’t sign you in with those details.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="login-shell">
      <section className="login-panel" aria-label="InfraTrack admin sign in">
        <div
          className="login-visual"
          style={{
            backgroundImage: `linear-gradient(180deg, rgba(14, 58, 76, 0.7) 0%, rgba(9, 47, 63, 0.58) 42%, rgba(6, 32, 42, 0.86) 100%), url(${matiAerial})`,
            backgroundSize: "cover",
            backgroundPosition: "center",
          }}
        >
          <div className="login-brand">
            <div className="login-brand-mark">
              <Building2 size={21} />
            </div>
            <div>
              <strong>InfraTrack</strong>
              <small>Admin Portal · Mati</small>
            </div>
          </div>
          <div className="login-visual-copy">
            <span className="login-eyebrow">LGU admin portal</span>
            <h1>
              A stronger Mati City starts with <em>better reporting.</em>
            </h1>
            <p>
              Monitor, verify, and manage infrastructure concerns for a safer,
              stronger, and more resilient Mati City.
            </p>
          </div>

          <div className="login-features" aria-label="InfraTrack benefits">
            <div>
              <ShieldCheck size={22} />
              <span>Safer<br />communities</span>
            </div>
            <div>
              <Landmark size={22} />
              <span>Efficient<br />governance</span>
            </div>
            <div>
              <UsersRound size={22} />
              <span>Responsive<br />public service</span>
            </div>
          </div>

          <div className="login-visual-footer">Mati City · Our city, our responsibility</div>
        </div>

        <div className="login-form-panel">
          <div className="login-header">
            <span className="login-eyebrow">Welcome back</span>
            <h2>Sign in to your account</h2>
            <p>Access the LGU dashboard and manage infrastructure reports for Mati City.</p>
          </div>

          <form className="login-form" onSubmit={submit}>
            <label htmlFor="admin-email">
              Email address
              <span className="login-field">
                <Mail size={17} />
                <input
                  id="admin-email"
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  placeholder="you@matioffice.gov.ph"
                  autoComplete="email"
                  autoFocus
                />
              </span>
            </label>

            <label htmlFor="admin-password">
              Password
              <span className="login-field">
                <LockKeyhole size={17} />
                <input
                  id="admin-password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  placeholder="Enter your password"
                  autoComplete="current-password"
                />
                <button
                  className="password-toggle"
                  type="button"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  onClick={() => setShowPassword((visible) => !visible)}
                >
                  {showPassword ? <EyeOff size={17} /> : <Eye size={17} />}
                </button>
              </span>
            </label>

            <div className="login-options">
              <label className="remember-me">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(event) => setRememberMe(event.target.checked)}
                />
                Remember me
              </label>
              <button className="text-button" type="button">
                Forgot password?
              </button>
            </div>

            {error && (
              <p className="login-error" role="alert">
                {error}
              </p>
            )}

            <button className="primary-button login-button" type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Signing in…" : "Sign in"} {!isSubmitting && <ArrowRight size={17} />}
            </button>
          </form>

          <p className="login-footer">Authorized city personnel only</p>
        </div>
      </section>
    </main>
  );
}
