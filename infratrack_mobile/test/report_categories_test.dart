import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/report_categories.dart';

void main() {
  test('report categories match the infrastructure scope', () {
    expect(reportCategories, [
      'Roads',
      'Public Buildings',
      'Streetlights',
      'Electric Poles',
      'Drainage',
    ]);
  });

  test('legacy category names normalize to the current labels', () {
    expect(normalizeReportCategory('Road'), 'Roads');
    expect(normalizeReportCategory('Lighting'), 'Streetlights');
    expect(normalizeReportCategory('Electric Pole'), 'Electric Poles');
  });

  test('out-of-scope historical labels are preserved, not misclassified', () {
    expect(normalizeReportCategory('Water'), 'Water');
  });
}
