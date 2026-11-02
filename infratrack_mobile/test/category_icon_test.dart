import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/category_icon.dart';

void main() {
  test('category icon asset paths cover only infrastructure categories', () {
    expect(categoryIconAsset('Roads'), 'assets/icons/roads.png');
    expect(
      categoryIconAsset('Public Buildings'),
      'assets/icons/public_buildings.png',
    );
    expect(categoryIconAsset('Drainage'), 'assets/icons/drainage.png');
    expect(categoryIconAsset('Streetlights'), 'assets/icons/street_lights.png');
    expect(
      categoryIconAsset('Electric Poles'),
      'assets/icons/electric_poles.png',
    );
    expect(categoryIconAsset('lighting'), 'assets/icons/street_lights.png');
    expect(categoryIconAsset('Unrelated'), isNull);
  });

  testWidgets('category image uses the requested icon dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: CategoryIcon(category: 'Roads', size: 15)),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 15);
    expect(image.height, 15);
    expect(image.fit, BoxFit.contain);
    expect((image.image as AssetImage).assetName, 'assets/icons/roads.png');
  });
}
