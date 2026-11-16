# Desktop Sidebar Collapse

## Intent

Give desktop InfraTrack Admin users more room for their current page by letting them collapse the navigation sidebar to an icon rail, matching the supplied reference.

## Scope and constraints

- Add a user-controlled expand/collapse toggle to the desktop sidebar.
- Keep all current navigation, active states, and pending-report count available while collapsed; provide accessible names and hover titles for icon-only links.
- Leave the existing mobile slide-out drawer unchanged and hide the desktop toggle on mobile.
- Use the existing React, Lucide, CSS variables, and responsive breakpoints; add no dependencies.
- Keep the collapsed width compact and the expanded width unchanged.

## Approaches

- Change the desktop sidebar width only: minimal, but provides no clear affordance to restore it.
- Add a responsive in-sidebar toggle and an icon rail: matches the reference while preserving the existing mobile drawer. Chosen.
- Replace the sidebar with a new navigation drawer: broader redesign and unnecessary for this request.

## Behavior and visual direction

Use the existing navy sidebar and teal active state. A compact chevron control in the sidebar header toggles between the current full navigation and a narrow, icon-only rail. The main content expands with the sidebar. On hover or keyboard focus, collapsed navigation items expose their full labels; accessible names remain available regardless of state. The desktop collapse state is in-memory and resets to expanded on page reload; persist it only if requested later.

## Success checks

- The desktop toggle expands and collapses the sidebar without changing the selected page.
- In the collapsed state, every available page action, settings, logout, active state, and issue count remain discoverable and usable.
- The mobile menu continues to work as a slide-out drawer and does not show the desktop toggle.
- Admin tests and production build pass.
