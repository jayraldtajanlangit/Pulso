import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/widgets/profile_avatar.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  testWidgets('shows uppercase initial fallback when avatarUrl is null',
      (tester) async {
    await pump(
      tester,
      const ProfileAvatar(displayName: 'jane'),
    );

    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('shows ? when displayName is null or empty', (tester) async {
    await pump(tester, const ProfileAvatar());
    expect(find.text('?'), findsOneWidget);

    await pump(tester, const ProfileAvatar(displayName: '   '));
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('no initial text is rendered when avatarUrl is provided',
      (tester) async {
    await pump(
      tester,
      const ProfileAvatar(
        avatarUrl: 'https://example.com/a.jpg',
        displayName: 'jane',
      ),
    );

    // The initial fallback is suppressed in favor of the network image.
    expect(find.text('J'), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('respects custom radius and produces a CircleAvatar',
      (tester) async {
    await pump(
      tester,
      const ProfileAvatar(displayName: 'A', radius: 32),
    );

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.radius, 32);
  });
}
