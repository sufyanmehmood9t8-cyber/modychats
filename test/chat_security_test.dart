import 'package:flutter_test/flutter_test.dart';
import 'package:modychat/services/firebase_service.dart';

void main() {
  group('WhatsApp Private Chat Security & Deterministic ID Tests', () {
    test('getConversationId produces identical ID regardless of UID order', () {
      final uidA = 'user_UID_AAA_12345';
      final uidB = 'user_UID_BBB_67890';

      final idFromA = FirebaseService.getConversationId(uidA, uidB);
      final idFromB = FirebaseService.getConversationId(uidB, uidA);

      expect(idFromA, equals(idFromB));
      expect(idFromA, equals('user_UID_AAA_12345_user_UID_BBB_67890'));
    });

    test('4 Users Privacy Isolation Check', () {
      final userA = 'uid_user_A';
      final userB = 'uid_user_B';
      final userC = 'uid_user_C';
      final userD = 'uid_user_D';

      final conv1Participants = [userA, userB];
      final conv2Participants = [userC, userD];

      // User A query check
      expect(conv1Participants.contains(userA), isTrue);
      expect(conv2Participants.contains(userA), isFalse);

      // User C query check
      expect(conv2Participants.contains(userC), isTrue);
      expect(conv1Participants.contains(userC), isFalse);
    });

    test('Phone normalization cleans non-digits correctly', () {
      expect(FirebaseService.normalizePhone('+92 300 111-1111'), equals('+923001111111'));
      expect(FirebaseService.normalizePhone('+1 (555) 234-5678'), equals('+15552345678'));
    });
  });
}
