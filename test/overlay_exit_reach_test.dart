import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/how_to_play.dart';

/// Short phone windows (browser bars, landscape) where a card can be taller
/// than the screen. The way out of the card must stay on screen without
/// scrolling.
const _sizes = [Size(360, 560), Size(320, 480), Size(640, 300)];

void main() {
  for (final size in _sizes) {
    testWidgets('How to play keeps Skip and Next on screen at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: HowToPlayOverlay(
                steps: [
                  HowToPlayStep(
                    Icons.gesture_rounded,
                    List.filled(
                      10,
                      'Draw one line through every star.',
                    ).join(' '),
                  ),
                  const HowToPlayStep(Icons.star_rounded, 'Last step.'),
                ],
                onClose: () => closed++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Skip', 'Next']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$label $size');
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: label);
      }
      await tester.tap(find.text('Skip'));
      expect(closed, 1);
    });
  }
}
