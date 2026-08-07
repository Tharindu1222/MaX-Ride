import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/main.dart';

void main() {
  testWidgets('MaX Ride driver app loads login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MaxRideDriverApp()));
    await tester.pumpAndSettle();

    expect(find.text('MaX Ride'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });
}
