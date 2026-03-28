// Basic smoke test for CycleTrack app.
//
// Verifies that the app builds successfully without crashing.

import 'package:flutter_test/flutter_test.dart';

import 'package:cycles/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // The app should display a loading indicator or main screen
    expect(find.byType(MyApp), findsOneWidget);
  });
}
