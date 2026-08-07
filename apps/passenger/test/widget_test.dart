import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passenger_app/main.dart';

void main() {
  testWidgets('MaX Ride passenger app loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaxRidePassengerApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('MaX Ride'), findsOneWidget);
    expect(find.textContaining('Send OTP'), findsOneWidget);
  });
}
