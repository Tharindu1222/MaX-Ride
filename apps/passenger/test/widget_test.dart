import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passenger_app/main.dart';

void main() {
  testWidgets('Premier Cabs passenger app loads welcome screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaxRidePassengerApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
    expect(find.textContaining('best ride'), findsOneWidget);
  });
}
