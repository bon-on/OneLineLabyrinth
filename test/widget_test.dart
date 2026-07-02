import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/main.dart';

void main() {
  testWidgets('One Line Labyrinth renders the game board', (tester) async {
    await tester.pumpWidget(const OneLineLabyrinthApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('One Line'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);
  });
}
