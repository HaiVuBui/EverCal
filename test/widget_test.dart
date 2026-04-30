import 'package:flutter_test/flutter_test.dart';

import 'package:ever_cal/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const MyCalendarApp());

    expect(find.byType(MyCalendarApp), findsOneWidget);
  });
}
