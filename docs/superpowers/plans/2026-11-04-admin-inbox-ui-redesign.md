# Admin Inbox UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the prototype-like Admin Inbox with a polished, responsive human-support workspace.

**Architecture:** Keep the React admin shell and current page routing. Rebuild `InboxPage.jsx` as a focused two-pane inbox, add reusable Lucide icons and scoped CSS, and update only the inbox navigation behavior required to support it.

**Tech Stack:** React, Vite, Lucide React, existing InfraTrack admin CSS tokens.

**Spec:** The attached screenshot and the citizen-support requirements in the prior request.

## Global Constraints

- Use the existing InfraTrack palette: navy `#0E3A4C`, deep navy `#092732`, teal `#1B8A83`, clay `#C1592B`, and sand `#F3EFE6`.
- Do not introduce a competing icon library; use Lucide React for controls and navigation.
- Keep thread states exactly `New`, `In progress`, and `Resolved`.
- Keep priorities exactly `Standard` and `Urgent`.
- Preserve desktop split-view behavior and mobile full-screen thread behavior.
- Citizen composer fields remain Category, Urgency, Barangay, Subject, Message, and attachments.

## Review Focus

- Icons that appear as literal Material Symbol names, such as `person_add`, `task_alt`, or `attach_file`; verify every visible control renders its Lucide icon.
- Long citizen subjects and barangay names; verify they truncate without breaking the layout.
- Long replies or multiline messages; verify composer height and message scrolling remain stable.
- Mobile navigation; verify selecting a thread hides the list and a back control restores it.
- Resolved, reopened, and closed threads; verify controls and status labels remain consistent after state changes.

---

### Task 1: Add Inbox UI contract tests

**Files:**
- Modify: `infratrack_admin/src/roleNavigation.test.js`
- Create: `infratrack_admin/src/pages/InboxPage.test.jsx`

- [ ] **Step 1: Add a source-level test asserting the production inbox exposes the required controls.**

Assert that `InboxPage.jsx` contains `Assign`, `Mark resolved`, `Close`, `Reopen`, `Category`, `Urgency`, `Barangay`, `Subject`, and `Message`.

- [ ] **Step 2: Add tests for desktop and mobile structure.**

Assert that the inbox exposes classes `inbox-thread-list` and `inbox-conversation`; assert that mobile back and thread-open behavior is wired through state.

- [ ] **Step 3: Run the tests and verify they fail before the redesign.**

Run: `cd infratrack_admin; node --test src/pages/InboxPage.test.jsx src/roleNavigation.test.js`

Expected: FAIL because the professional structure or contract is not implemented yet.

### Task 2: Rebuild InboxPage structure and interactions

**Files:**
- Modify: `infratrack_admin/src/pages/InboxPage.jsx`

- [ ] **Step 1: Replace Material-symbol text controls with Lucide components.**

Use `ArrowLeft`, `Paperclip`, `Send`, `UserPlus`, `CheckCircle2`, `RotateCcw`, and `CircleX` as controls.

- [ ] **Step 2: Give the workspace a clear desktop hierarchy.**

Implement:

```text
+----------------------+----------------------------------------+
| Citizen conversations| Thread subject and status               |
| status filters       | recipient details                        |
| thread rows          | conversation                             |
|                      | compact reply composer                   |
+----------------------+----------------------------------------+
```

Use one continuous workspace surface rather than nested cards or excessive labels.

- [ ] **Step 3: Make thread actions explicit and restrained.**

Keep primary reply actions visually subordinate to thread status. Use a single overflow menu for less frequent actions only if existing admin patterns support it; otherwise retain visible Assign, Mark resolved, Close, and Reopen controls.

- [ ] **Step 4: Keep mobile thread navigation full-screen.**

When a thread is selected, hide the list and render the conversation with a back button. When it is closed, restore the scrollable thread list.

### Task 3: Rebuild Inbox CSS into a cohesive visual system

**Files:**
- Modify: `infratrack_admin/src/styles.css`

- [ ] **Step 1: Define the inbox layout dimensions.**

Use a desktop thread rail of `340px`, flexible conversation area, and the remaining viewport height below the admin topbar. Remove excessive outer padding and nested card surfaces.

- [ ] **Step 2: Style thread scanning hierarchy.**

Use a `40px` avatar, sender name in semibold, subject in medium, preview in muted text, fixed time column, and priority/status accents with no badge overload.

- [ ] **Step 3: Style conversation and composer as professional messaging surfaces.**

Use restrained sender bubbles, a maximum message width of `680px`, metadata compactly arranged under the subject, a sticky composer, and visible keyboard focus.

- [ ] **Step 4: Add mobile overrides.**

At `760px` and below, the admin inbox occupies the available viewport, the thread list fills the screen, and the active conversation becomes the only visible pane.

### Task 4: Align navigation and unread state

**Files:**
- Modify: `infratrack_admin/src/App.jsx`
- Modify: `infratrack_admin/src/roleNavigation.js`
- Modify: `infratrack_admin/src/roleNavigation.test.js`

- [ ] **Step 1: Keep Inbox available to LGU and barangay admin roles.**

Maintain the existing Operations-group placement and an unread count based on real current thread state rather than a fixed display.

- [ ] **Step 2: Add the Inbox icon to the existing Lucide icon map.**

Use Lucide `MessageSquare`; remove any raw icon text path from this navigation item.

### Task 5: Verify the redesigned inbox

- [ ] **Step 1: Run focused unit tests.**

Run: `cd infratrack_admin; node --test src/pages/InboxPage.test.jsx src/roleNavigation.test.js`

Expected: PASS.

- [ ] **Step 2: Run the production build.**

Run: `cd infratrack_admin; npm run build`

Expected: PASS; only existing dependency or bundle-size warnings may remain.

- [ ] **Step 3: Perform a visual review at desktop and mobile widths.**

Verify:
- no literal Material Symbol names are visible;
- desktop conversation and thread list fill the workspace cleanly;
- mobile opens one full-screen view at a time;
- urgent, standard, new, in-progress, resolved, assign, reopen, close, and reply interactions remain legible.

## Self-review

The plan covers the screenshot’s most visible defects: ambiguous cards, exposed icon labels, weak scanning hierarchy, oversized control labels, and cramped responsive behavior. The remaining work should stay inside the production React admin and existing design tokens.
