// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/app.dart';

void main() {
  testWidgets('앱이 정상적으로 부팅된다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TeamMeetingApp()));
    // 한 번의 렌더 사이클만 돌려 초기 위젯 트리가 그려졌는지만 확인한다.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
