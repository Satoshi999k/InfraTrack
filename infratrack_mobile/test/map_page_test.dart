import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/api_service.dart';
import 'package:infatrack/main.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('map starts centered on a Central resident barangay', (
    tester,
  ) async {
    ApiService.currentUser = {'barangay': 'Barangay Central'};
    addTearDown(() => ApiService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: MapPage()));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, const LatLng(6.9612515, 126.2069944));
  });

  testWidgets('map starts centered on a Dawan resident barangay', (
    tester,
  ) async {
    ApiService.currentUser = {'barangay': 'Dawan'};
    addTearDown(() => ApiService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: MapPage()));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, const LatLng(6.8993278, 126.1510600));
  });
}
