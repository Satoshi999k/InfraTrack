const operations = {
  label: "Operations",
  items: [
    ["overview", "Overview"],
    ["queue", "Issue Queue"],
    ["map", "Infrastructure Map"],
    ["analytics", "Analytics & Reports"],
  ],
};

const adminManagement = {
  label: "Administration",
  items: [
    ["users", "User Management"],
    ["announce", "Public Advisory"],
    ["published", "Published Advisories"],
    ["logs", "Activity Logs"],
  ],
};

const barangayManagement = {
  label: "Barangay",
  items: [
    ["users", "Residents"],
    ["announce", "Public Advisory"],
    ["published", "Published Advisories"],
    ["logs", "Activity Logs"],
  ],
};

export function getNavigationGroups(role) {
  if (!["lgu", "admin", "barangay_staff"].includes(role)) return [];
  return [
    operations,
    role === "barangay_staff" ? barangayManagement : adminManagement,
  ];
}

export function canAccessAdminPage(role, page) {
  if (page === "settings") return ["lgu", "admin", "barangay_staff"].includes(role);
  return getNavigationGroups(role).some((group) =>
    group.items.some(([pageId]) => pageId === page),
  );
}
