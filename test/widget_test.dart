import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:developercontrol/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots MaterialApp', (tester) async {
    await tester.pumpWidget(const DeveloperControlApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump();
  });
}
