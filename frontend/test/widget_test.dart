// Basic smoke test — verifies the app boots and the login screen renders.

import 'package:flutter_test/flutter_test.dart';

import 'package:hunger_cafe/main.dart';

void main() {
  testWidgets('App launches and shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HungerApp());

    // Wait for the auth restore Future to complete.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sign in'), findsOneWidget);
  });
}
