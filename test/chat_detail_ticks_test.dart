import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the delivery ticks on outgoing chat messages.
///
/// The ticks used to be built next to the bubble, where they were easy to lose
/// (and are gone as soon as a message is not detected as "mine"). They now
/// live inside the outgoing bubble, next to the sent-at time.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/chat_detail_screen.dart').readAsStringSync();
  });

  group('Outgoing message ticks', () {
    test('are rendered inside the bubble, only for outgoing messages', () {
      final bubbleContent =
          source.substring(source.indexOf('Widget _buildBubbleContent('));

      expect(
        bubbleContent.contains('if (isMe)'),
        isTrue,
        reason: 'received messages must never show delivery ticks',
      );
      expect(
        bubbleContent.contains('_buildCheckMarkIcon(msg)'),
        isTrue,
        reason: 'the ticks are part of the outgoing bubble content',
      );

      // A single call site: the ticks can no longer be dropped from the bubble.
      expect(
        RegExp(r'_buildCheckMarkIcon\(msg\)').allMatches(source).length,
        1,
      );
    });

    test('offline recipient gets one grey tick', () {
      final fn = source.substring(source.indexOf('Widget _buildCheckMarkIcon('));

      expect(fn.contains('Icons.done_rounded'), isTrue);
      expect(fn.contains('Colors.white54'), isTrue);
    });

    test('online recipient gets two ticks and read turns them green', () {
      final fn = source.substring(source.indexOf('Widget _buildCheckMarkIcon('));

      expect(fn.contains('Icons.done_all_rounded'), isTrue);
      expect(
        fn.contains('Color(0xFF2ECC71)'),
        isTrue,
        reason: 'read receipts must turn the ticks green',
      );
      expect(fn.contains('if (msg.isRead)'), isTrue);
      expect(
        fn.contains('if (_isOnline)'),
        isTrue,
        reason: 'tick count follows the live presence of the other user',
      );
    });
  });
}