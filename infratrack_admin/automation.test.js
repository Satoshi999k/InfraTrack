import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeIssueText, computeDuplicateMatch, escalateIssueSeverity } from './automation.js';
import { getBarangayForCoordinates, validateBarangayCoordinates } from './barangay-boundaries.js';

test('duplicate detection catches same-issue reports in the same barangay', () => {
  const existing = {
    id: 42,
    reporter_id: 17,
    category: 'Roads',
    location: 'Brgy. Central',
    title: 'Deep pothole along Rizal Street',
    latitude: 6.953,
    longitude: 126.228,
    created_at: '2026-09-19T08:00:00Z',
  };

  const current = {
    reporter_id: 17,
    category: 'Roads',
    location: 'Brgy. Central',
    title: 'Pothole on Rizal St near the market',
    latitude: 6.9531,
    longitude: 126.2282,
  };

  assert.equal(computeDuplicateMatch(current, existing), true);
  assert.equal(normalizeIssueText('Road repair near Rizal St.').includes('rizal'), true);
});

test('duplicate detection does not match reports from different residents', () => {
  const existing = {
    reporter_id: 17,
    category: 'Roads',
    location: 'Brgy. Central',
    title: 'Deep pothole along Rizal Street',
    latitude: 6.953,
    longitude: 126.228,
  };
  const current = {
    reporter_id: 18,
    category: 'Roads',
    location: 'Brgy. Central',
    title: 'Deep pothole along Rizal Street',
    latitude: 6.953,
    longitude: 126.228,
  };

  assert.equal(computeDuplicateMatch(current, existing), false);
});

test('duplicate detection does not match reports without resident identities', () => {
  const report = {
    category: 'Roads',
    location: 'Brgy. Central',
    title: 'Deep pothole along Rizal Street',
    latitude: 6.953,
    longitude: 126.228,
  };

  assert.equal(computeDuplicateMatch(report, { ...report, reporter_id: 17 }), false);
  assert.equal(computeDuplicateMatch({ ...report, reporter_id: 17 }, report), false);
});

test('priority escalation raises delayed items by urgency level', () => {
  assert.equal(escalateIssueSeverity('Low', 96), 'Medium');
  assert.equal(escalateIssueSeverity('Medium', 72), 'High');
  assert.equal(escalateIssueSeverity('High', 48), 'Critical');
  assert.equal(escalateIssueSeverity('Resolved', 24), 'Resolved');
});

test('priority escalation uses configured workflow thresholds', () => {
  const thresholds = { low: 24, medium: 12, high: 6 };
  assert.equal(escalateIssueSeverity('Low', 23, thresholds), 'Low');
  assert.equal(escalateIssueSeverity('Low', 24, thresholds), 'Medium');
  assert.equal(escalateIssueSeverity('Medium', 12, thresholds), 'High');
  assert.equal(escalateIssueSeverity('High', 6, thresholds), 'Critical');
});

test('barangay validation recognizes a report inside a valid subdivision', () => {
  assert.equal(getBarangayForCoordinates(6.9632, 126.2103), 'Brgy. Central');
  assert.equal(validateBarangayCoordinates({ latitude: 6.9632, longitude: 126.2103, location: 'Brgy. Central' }).valid, true);
  assert.equal(validateBarangayCoordinates({ latitude: 6.9632, longitude: 126.2103, location: 'Brgy. Dawan' }).valid, false);
});

test('city fallback accepts Mati locations not covered by a barangay polygon', () => {
  assert.equal(
    validateBarangayCoordinates({
      latitude: 6.95321,
      longitude: 126.21202,
      location: 'Mati City',
    }).valid,
    true,
  );
});
