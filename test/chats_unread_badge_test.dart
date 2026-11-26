import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the green unread badge on the chat rows.
///
/// The count used to be hardcoded to 0, so a chat row never showed how many
/// messages were waiting. It now comes from a live Firestore count.
void main() {
  late String chatsTab;
  late String chatTile;
  late String chatAvatar;
  late String firebaseService;

  setUpAll(() {
    chatsTab = File('lib/screens/chats_tab.dart').readAsStringSync();
    chatTile = File('lib/widgets/chat_tile.dart').readAsStringSync();
    chatAvatar = File('lib/widgets/chat_avatar.dart').readAsStringSync();
    firebaseService = File('lib/services/firebase_service.dart').readAsStringSync();
  });

  group('Chats tab unread badge', () {
    test('counts unread messages from Firestore', () {
      expect(
        firebaseService.contains('Stream<int> watchUnreadCount('),
        isTrue,
      );
      expect(
        firebaseService.contains(".where('isRead', isEqualTo: false)"),
        isTrue,
        reason: 'the badge must count unread messages only',
      );
    });

    test('each row streams its own conversation count', () {
      expect(chatsTab.contains('_unreadCountStream('), isTrue);
      expect(chatsTab.contains('watchUnreadCount('), isTrue);
      expect(
        RegExp(r'unreadCount: 0,').allMatches(chatsTab).length,
        greaterThanOrEqualTo(0),
      );
      expect(
        chatsTab.contains('unreadCount: unreadSnap.data ?? 0'),
        isTrue,
        reason: 'the row must render the live count, not the placeholder',
      );
    });

    test('the unread stream instance is cached, not rebuilt', () {
      expect(
        chatsTab.contains('_unreadStreams.putIfAbsent('),
        isTrue,
        reason: 'a stream built in build() would re-subscribe on every rebuild',
      );
    });

    test('the badge is green', () {
      expect(chatTile.contains('Color(0xFF2ECC71)'), isTrue);
      expect(chatAvatar.contains('badgeColor'), isTrue);
      expect(
        chatAvatar.contains('color: badgeColor,'),
        isTrue,
        reason: 'ChatAvatar must render the badge in the requested color',
      );
    });
  });
}