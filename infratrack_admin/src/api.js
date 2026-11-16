const apiEnv = typeof import.meta !== "undefined" && import.meta.env ? import.meta.env : {};
const configuredApiUrl = apiEnv.VITE_API_URL?.trim();
const isLocalApiUrl = /^https?:\/\/(?:localhost|127(?:\.\d{1,3}){3}|\[::1\])(?::\d+)?(?:\/|$)/i.test(
	configuredApiUrl || "",
);
export const API_BASE =
	(configuredApiUrl && (apiEnv.DEV || !isLocalApiUrl) ? configuredApiUrl : "") ||
	(apiEnv.DEV ? "http://localhost:3001/api" : "/api");

export const SESSION_EXPIRED_EVENT = "infratrack:session-expired";

export function apiFetch(path, options = {}) {
	const token =
		(globalThis.localStorage && globalThis.localStorage.getItem("infratrack.adminToken")) ||
		(globalThis.sessionStorage && globalThis.sessionStorage.getItem("infratrack.adminToken"));
	const headers = new Headers(options.headers || {});
	if (token) headers.set("Authorization", `Bearer ${token}`);
	return fetch(`${API_BASE}${path}`, { ...options, headers }).then((response) => {
		const activeToken =
			(globalThis.localStorage &&
				globalThis.localStorage.getItem("infratrack.adminToken")) ||
			(globalThis.sessionStorage &&
				globalThis.sessionStorage.getItem("infratrack.adminToken"));
		if (token && token === activeToken && response.status === 401) {
			globalThis.window?.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
		}
		return response;
	});
}
