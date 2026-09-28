import 'package:flutter_test/flutter_test.dart';
import 'package:sabzisetu_flutter/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SabziSetuApp());
    expect(find.byType(SabziSetuApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
