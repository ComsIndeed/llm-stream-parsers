import 'package:flutter_test/flutter_test.dart';
import 'package:llm_tag_parser_example/main.dart';

void main() {
  testWidgets('Playground App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our playground app title is found
    expect(find.byType(MyApp), findsOneWidget);
  });
}
