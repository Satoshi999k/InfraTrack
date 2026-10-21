const reportCategories = [
  'Roads',
  'Public Buildings',
  'Streetlights',
  'Electric Poles',
  'Drainage',
];

String normalizeReportCategory(String? category) {
  final normalized = category?.trim().toLowerCase();
  return switch (normalized) {
    'road' || 'roads' => 'Roads',
    'public building' || 'public buildings' => 'Public Buildings',
    'lighting' || 'streetlight' || 'streetlights' => 'Streetlights',
    'electric pole' || 'electric poles' => 'Electric Poles',
    'drainage' => 'Drainage',
    _ => category?.trim() ?? '',
  };
}
