import test from "node:test";
import assert from "node:assert/strict";

import {
  getAdvisoryReadScope,
  getAdvisoryScope,
  getReportScope,
} from "./advisoryAccess.js";

const reports = [
  { public_id: "CENTRAL-1", location: "Brgy. Central" },
  { public_id: "DAWAN-1", location: "Brgy. Dawan" },
];

const advisories = [
  { id: 1, barangay: "Brgy. Central", audience: "Brgy. Central" },
  { id: 2, barangay: "Brgy. Dawan", audience: "Brgy. Dawan" },
  { id: 3, barangay: null, audience: "All barangays" },
];

function visibleRecords(records, scope) {
  return records.filter(scope.allows);
}

test("Central staff see Central reports and barangay-wide advisories only", () => {
  const staff = { role: "barangay_staff", barangay: "Brgy. Central" };
  const reportScope = getReportScope(staff, "r");
  const advisoryScope = getAdvisoryReadScope(staff, "a");

  assert.equal(reportScope.sql, " AND r.location = ?");
  assert.deepEqual(reportScope.params, ["Brgy. Central"]);
  assert.equal(
    advisoryScope.sql,
    " AND (a.barangay = ? OR a.audience = 'All barangays')",
  );
  assert.deepEqual(advisoryScope.params, ["Brgy. Central"]);
  assert.deepEqual(visibleRecords(reports, reportScope), [reports[0]]);
  assert.deepEqual(visibleRecords(advisories, advisoryScope), [
    advisories[0],
    advisories[2],
  ]);
});

test("Dawan staff see Dawan reports and barangay-wide advisories only", () => {
  const staff = { role: "barangay_staff", barangay: "Brgy. Dawan" };
  const reportScope = getReportScope(staff, "r");
  const advisoryScope = getAdvisoryReadScope(staff, "a");

  assert.equal(reportScope.sql, " AND r.location = ?");
  assert.deepEqual(reportScope.params, ["Brgy. Dawan"]);
  assert.deepEqual(advisoryScope.params, ["Brgy. Dawan"]);
  assert.deepEqual(visibleRecords(reports, reportScope), [reports[1]]);
  assert.deepEqual(visibleRecords(advisories, advisoryScope), [
    advisories[1],
    advisories[2],
  ]);
});

test("Central and Dawan staff cannot edit or archive another barangay's advisories", () => {
  const centralScope = getAdvisoryScope({
    role: "barangay_staff",
    barangay: "Brgy. Central",
  });
  const dawanScope = getAdvisoryScope({
    role: "barangay_staff",
    barangay: "Brgy. Dawan",
  });

  assert.equal(centralScope.sql, " AND advisories.barangay = ?");
  assert.deepEqual(centralScope.params, ["Brgy. Central"]);
  assert.deepEqual(dawanScope.params, ["Brgy. Dawan"]);
  assert.equal(centralScope.allows(advisories[0]), true);
  assert.equal(centralScope.allows(advisories[1]), false);
  assert.equal(dawanScope.allows(advisories[1]), true);
  assert.equal(dawanScope.allows(advisories[0]), false);
  assert.equal(centralScope.allows(advisories[2]), false);
  assert.equal(dawanScope.allows(advisories[2]), false);
});

test("LGU administrators retain city-wide advisory access", () => {
  const staff = { role: "barangay_staff", barangay: "Brgy. Central" };
  const lguScope = getAdvisoryReadScope({ role: "lgu" });
  const adminScope = getAdvisoryScope({ role: "admin" });

  assert.equal(lguScope.sql, "");
  assert.deepEqual(lguScope.params, []);
  assert.deepEqual(visibleRecords(advisories, lguScope), advisories);
  assert.equal(adminScope.sql, "");
  assert.deepEqual(adminScope.params, []);
  assert.deepEqual(visibleRecords(advisories, adminScope), advisories);
  assert.equal(getReportScope(staff).params[0], staff.barangay);
});
