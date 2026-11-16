export function getSidebarToggle(collapsed) {
  return {
    nextCollapsed: !collapsed,
    label: collapsed ? "Expand sidebar" : "Collapse sidebar",
  };
}
