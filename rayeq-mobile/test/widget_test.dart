import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/main.dart';

void main() {
  testWidgets('Rayeq starts with the Arabic brand', (tester) async {
    await tester.pumpWidget(const RayeqApp());
    expect(find.text('رايق'), findsOneWidget);
    expect(find.text('خلّينا نبدأ'), findsOneWidget);
  });
}
