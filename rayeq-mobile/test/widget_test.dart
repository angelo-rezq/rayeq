import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/main.dart';
import 'package:rayeq/brand_wordmark.dart';

void main() {
  testWidgets('Rayeq starts with the Arabic brand', (tester) async {
    await tester.pumpWidget(const RayeqApp());
    await tester.pumpAndSettle();
    expect(find.byType(RayeqArabicWordmark), findsOneWidget);
    expect(find.text('خلّينا نبدأ'), findsOneWidget);
  });
}
