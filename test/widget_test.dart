
import 'package:flutter_test/flutter_test.dart';
import 'package:my_week/main.dart';

void main() {
  testWidgets('My Week app opens', (WidgetTester tester) async {
    await tester.pumpWidget(const MyWeekApp());
    await tester.pumpAndSettle();

    expect(find.text('My Week'), findsOneWidget);
  });
}
