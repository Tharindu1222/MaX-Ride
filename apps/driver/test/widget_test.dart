import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/main.dart';

void main() {
  testWidgets('MaX Ride driver app loads welcome screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MaxRideDriverApp()));
    await tester.pumpAndSettle();

    expect(find.text('Find Your'), findsOneWidget);
    expect(find.text('Perfect Ride'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
