import test from 'node:test';
import assert from 'node:assert/strict';

import { searchAddressLocations } from './mapSearch.js';

test('falls back to local issue matches when the geocoder request fails', async () => {
  const issues = [
    { title: 'Road repair', location: 'Mati City', latitude: 6.95, longitude: 126.2 },
    { title: 'Water leak', location: 'Dahican', latitude: 6.94, longitude: 126.27 },
  ];

  const results = await searchAddressLocations('road', issues, {
    fetchImpl: async () => {
      throw new Error('Failed to fetch');
    },
  });

  assert.equal(results.length, 1);
  assert.equal(results[0].display_name, 'Issue report: Road repair · Mati City');
});


test('returns Nominatim matches when the geocoder succeeds', async () => {
  const issues = [{ title: 'Road repair', location: 'Mati City', latitude: 6.95, longitude: 126.2 }];

  const results = await searchAddressLocations('dahican', issues, {
    fetchImpl: async () => ({
      ok: true,
      json: async () => [{
        lat: '6.946',
        lon: '126.26',
        display_name: 'Dahican, Mati City, Davao Oriental',
      }],
    }),
  });

  assert.equal(results.length, 1);
  assert.equal(results[0].display_name, 'Dahican, Mati City, Davao Oriental');
});
