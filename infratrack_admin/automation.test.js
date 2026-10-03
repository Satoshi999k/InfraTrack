import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeIssueText, computeDuplicateMatch, escalateIssueSeverity } from './automation.js';
import { getBarangayForCoordinates, validateBarangayCoordinates } from './barangay-boundaries.js';

test('duplicate detection catches same-issue reports in the same barangay', () => {
  const existing = {
    id: 42,
    category: 'Roads',
    location: 'Brgy. Central',
    title: 'Deep pothole along Rizal Street',
    latitude: 6.953,
    longitude: 126.228,
    created_at: '2026-09-19T08:00:00Z',
  };

  const current = {
    category: 'Roads',
    location: 'Brgy. Central',
    title: 'Pothole on Rizal St near the market',
    latitude: 6.9531,
    longitude: 126.2282,
  };

  assert.equal(computeDuplicateMatch(current, existing), true);
  assert.equal(normalizeIssueText('Road repair near Rizal St.').includes('rizal'), true);
});

test('priority escalation raises delayed items by urgency level', () => {
  assert.equal(escalateIssueSeverity('Low', 96), 'Medium');
  assert.equal(escalateIssueSeverity('Medium', 72), 'High');
  assert.equal(escalateIssueSeverity('High', 48), 'Critical');
  assert.equal(escalateIssueSeverity('Resolved', 24), 'Resolved');
});

test('barangay validation recognizes a report inside a valid subdivision', () => {
  assert.equal(getBarangayForCoordinates(6.9632, 126.2103), 'Brgy. Central');
  assert.equal(validateBarangayCoordinates({ latitude: 6.9632, longitude: 126.2103, location: 'Brgy. Central' }).valid, true);
  assert.equal(validateBarangayCoordinates({ latitude: 6.9632, longitude: 126.2103, location: 'Brgy. Dawan' }).valid, false);
});
