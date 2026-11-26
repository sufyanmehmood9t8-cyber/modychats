import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the "Bad state: Stream has already been listened to"
/// crash that happened when Chat Detail was opened.
///
/// `FirebaseService.watchUserProfile` is an `async*` generator, so the stream
/// it returns is SINGLE-SUBSCRIPTION. Chat Detail used to both `listen()` to it
/// in `initState` and hand the same instance to a `StreamBuilder`, which threw
/// the state error as soon as a chat was opened.
void main() {
  group('Single-subscription stream contract', () {
    test('a second listener on a single-subscription stream throws', () async {
      final stream = _profileLikeStream();

      final first = stream.listen((_) {});
      addTearDown(first.cancel);

      expect(
        () => stream.listen((_) {}),
        throwsStateError,
        reason: 'async* streams may only be listened to once',
      );
    });
  });

  group('ChatDetailScreen stream wiring', () {
    late String source;

    setUpAll(() {
      source =
          File('lib/screens/chat_detail_screen.dart').readAsStringSync();
    });

    test('listens to the other-user profile stream exactly once', () {
      final listeners =
          RegExp(r'_otherProfileStream\.listen\(').allMatches(source).length;

      expect(
        listeners,
        1,
        reason: 'watchUserProfile() is single-subscription: one listener only',
      );
    });

    test('never binds the profile stream to a StreamBuilder', () {
      expect(
        RegExp(r'stream:\s*_otherProfileStream').hasMatch(source),
        isFalse,
        reason: 'a StreamBuilder on the same instance is a second listener',
      );
    });

    test('cancels the profile subscription on dispose', () {
      expect(source.contains('_otherProfileSub?.cancel();'), isTrue);
    });

    test('creates the Firestore streams once in initState, not in build', () {
      expect(
        source.contains(
            '_messagesStream = _firebaseService.getPrivateMessagesStream(_conversationId);'),
        isTrue,
      );
      expect(
        source.contains(
            '_conversationStream = _firebaseService.watchConversationStream(_conversationId);'),
        isTrue,
      );

      // No stream may be constructed inside a builder/build, otherwise every
      // rebuild attaches an extra Firestore listener.
      expect(
        RegExp(r'stream:\s*_firebaseService\.getPrivateMessagesStream')
            .hasMatch(source),
        isFalse,
      );
      expect(
        RegExp(r'stream:\s*FirebaseFirestore\.instance').hasMatch(source),
        isFalse,
      );
    });

    test('keeps the chat private: conversation id stays UID based', () {
      expect(
        source.contains(
            '_conversationId = FirebaseService.getConversationId('),
        isTrue,
      );
    });
  });
}

/// Mirrors the shape of `watchUserProfile` (`async*` => single subscription).
Stream<String> _profileLikeStream() async* {
  yield 'profile';
  yield 'profile-updated';
}
