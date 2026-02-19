import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_meta_wearables_example/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MetaWearablesExampleApp());

    expect(find.text('Meta Wearables'), findsOneWidget);
    expect(find.text('Initialize SDK'), findsOneWidget);
  });
}
