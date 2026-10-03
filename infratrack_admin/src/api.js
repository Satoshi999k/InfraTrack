const apiEnv = typeof import.meta !== "undefined" && import.meta.env ? import.meta.env : {};
export const API_BASE = apiEnv.VITE_API_URL || "http://localhost:3001/api";

export function apiFetch(path, options = {}) {
	const token =
		(globalThis.localStorage && globalThis.localStorage.getItem("infratrack.adminToken")) ||
		(globalThis.sessionStorage && globalThis.sessionStorage.getItem("infratrack.adminToken"));
	const headers = new Headers(options.headers || {});
	if (token) headers.set("Authorization", `Bearer ${token}`);
	return fetch(`${API_BASE}${path}`, { ...options, headers });
}
