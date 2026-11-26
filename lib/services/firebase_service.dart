import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Active Logged-in User Profile (defaults to User A: +92 300 1111111)
  static String currentUserPhone = '+923001111111';
  static String currentUserName = 'User A';

  // Get current Firebase Auth UID (falls back to normalized phone if unauthenticated in dev/tests)
  String get currentUid =>
      _auth.currentUser?.uid ?? normalizePhone(currentUserPhone);

  static void setCurrentUser(String phone, String name) {
    currentUserPhone = normalizePhone(phone);
    currentUserName = name;
  }

  // Normalize phone numbers for unique key matching
  static String normalizePhone(String phone) {
    if (phone.isEmpty) return 'unknown';
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.isEmpty ? phone : cleaned;
  }

  // Deterministic 1-on-1 Conversation ID based on two participant UIDs or phone numbers
  static String getConversationId(String id1, String id2) {
    final clean1 = id1.trim();
    final clean2 = id2.trim();
    List<String> list = [clean1, clean2]..sort();
    return '${list[0]}_${list[1]}';
  }

  // Legacy getChatId method for backwards compatibility
  static String getChatId(String phone1, String phone2) {
    return getConversationId(normalizePhone(phone1), normalizePhone(phone2));
  }

  // ─── USER & PHONE LOOKUP INDEX ─────────────────────────────────────────────

  // Save / Update user global profile in Firestore under users/{uid} & phoneIndex
  Future<void> updateUserProfile({
    required String phone,
    String? name,
    String? profileImage,
    String? about,
    String? gender,
  }) async {
    final norm = normalizePhone(phone);
    final uid = currentUid;
    final Map<String, dynamic> data = {
      'uid': uid,
      'phone': phone,
      'normalizedPhone': norm,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) {
      data['name'] = name;
    }
    if (profileImage != null) {
      data['profile_image'] = profileImage;
      data['imagePath'] = profileImage;
    }
    if (about != null) {
      data['about'] = about;
    }
    if (gender != null) {
      data['gender'] = gender;
    }

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    await _db.collection('users').doc(norm).set(data, SetOptions(merge: true));

    // Phone index lookup mapping phone to uid
    await _db.collection('phoneIndex').doc(norm).set({
      'uid': uid,
      'phone': phone,
      'normalizedPhone': norm,
    }, SetOptions(merge: true));
  }

  // Set automatic user online/offline presence
  Future<void> setUserPresence(bool isOnline) async {
    final uid = currentUid;
    if (uid.isEmpty || uid == 'unknown') return;

    final data = {
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };

    try {
      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      final norm = normalizePhone(currentUserPhone);
      if (norm.isNotEmpty && norm != 'unknown') {
        await _db.collection('users').doc(norm).set(data, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // Lookup target User UID by phone number
  Future<String> getUidByPhone(String phone) async {
    final norm = normalizePhone(phone);
    if (norm.isEmpty || norm == 'unknown') return phone;

    try {
      final doc = await _db.collection('phoneIndex').doc(norm).get();
      if (doc.exists && doc.data()?.containsKey('uid') == true) {
        return doc.data()!['uid'].toString();
      }

      final userDoc = await _db.collection('users').doc(norm).get();
      if (userDoc.exists && userDoc.data()?.containsKey('uid') == true) {
        return userDoc.data()!['uid'].toString();
      }
    } catch (_) {}

    return norm; // Fallback to normalized phone if UID missing
  }

  // ─── PROFILE LOOKUP (single source of truth: users collection) ────────────

  // Resolve a user document reference for an identifier that may be a UID or
  // a phone number. Returns null when no profile document exists.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveUserDoc(
      String identifier) async {
    final id = identifier.trim();
    if (id.isEmpty) return null;

    final byId = await _db.collection('users').doc(id).get();
    if (byId.exists) return byId;

    final uid = await getUidByPhone(id);
    if (uid.isNotEmpty && uid != id) {
      final byUid = await _db.collection('users').doc(uid).get();
      if (byUid.exists) return byUid;
    }

    final norm = normalizePhone(id);
    if (norm.isNotEmpty && norm != 'unknown' && norm != id) {
      final byPhone = await _db.collection('users').doc(norm).get();
      if (byPhone.exists) return byPhone;
    }

    return null;
  }

  // Load a single user profile by UID (falls back to phone lookup).
  Future<UserProfile?> getUserProfileById(String identifier) async {
    try {
      final doc = await _resolveUserDoc(identifier);
      if (doc == null) return null;
      return UserProfile.fromDocument(doc);
    } catch (_) {
      return null;
    }
  }

  // Live profile stream for a single user (UID or phone identifier).
  //
  // IMPORTANT: this is built with `async*`, so it is a SINGLE-SUBSCRIPTION
  // stream — attaching a second listener throws
  // "Bad state: Stream has already been listened to". Call it once and keep a
  // single listener; use [getUserProfileById] for one-off reads. Firestore
  // streams in this class (snapshots()) are multi-subscription and may be
  // shared, but should still be created once and reused rather than rebuilt.
  Stream<UserProfile> watchUserProfile(String identifier) async* {
    try {
      final doc = await _resolveUserDoc(identifier);
      if (doc == null) {
        yield UserProfile(uid: identifier.trim());
        return;
      }
      yield UserProfile.fromDocument(doc);
      await for (final snap in doc.reference.snapshots()) {
        yield snap.exists
            ? UserProfile.fromDocument(snap)
            : UserProfile(uid: identifier.trim());
      }
    } catch (_) {
      yield UserProfile(uid: identifier.trim());
    }
  }

  // De-duplicated stream of every registered ModyChat user profile.
  // Note: each profile exists twice in Firestore (users/{uid} and
  // users/{normalizedPhone}); entries are merged on the 'uid' field.
  Stream<List<UserProfile>> watchRegisteredUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      final Map<String, UserProfile> byUid = {};
      for (final doc in snapshot.docs) {
        final profile = UserProfile.fromDocument(doc);
        if (profile.uid.isEmpty) continue;
        final existing = byUid[profile.uid];
        if (existing == null) {
          byUid[profile.uid] = profile;
        } else if (doc.id == profile.uid) {
          // The UID-keyed document is the canonical profile (it is written
          // last), so it wins and the phone mirror only fills empty fields.
          byUid[profile.uid] = profile.mergeWith(existing);
        } else {
          byUid[profile.uid] = existing.mergeWith(profile);
        }
      }
      return byUid.values.toList();
    });
  }

  // ─── PRIVATE CONVERSATIONS & MESSAGES ──────────────────────────────────────

  // Send Message inside WhatsApp-style private conversation: conversations/{conversationId}/messages
  Future<void> sendMessage({
    required String senderPhone,
    required String receiverPhone,
    required String text,
    String senderUid = '',
    String receiverUid = '',
    String type = 'text',
    String mediaPath = '',
    String fileName = '',
    String fileSize = '',
    String contactName = '',
    String contactPhone = '',
    String locationAddress = '',
    int audioDurationSeconds = 0,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
  }) async {
    final actualSenderUid = senderUid.isNotEmpty ? senderUid : currentUid;
    final actualReceiverUid = receiverUid.isNotEmpty
        ? receiverUid
        : (receiverPhone.isNotEmpty
            ? await getUidByPhone(receiverPhone)
            : receiverUid);

    final normSenderPhone = normalizePhone(senderPhone);
    final normReceiverPhone = normalizePhone(receiverPhone);

    // Deterministic Conversation ID
    final conversationId = getConversationId(actualSenderUid, actualReceiverUid);

    String displaySummary = text;
    if (type == 'image') displaySummary = '📷 Photo';
    if (type == 'file') displaySummary = '📄 $fileName';
    if (type == 'contact') displaySummary = '👤 Contact: $contactName';
    if (type == 'location') displaySummary = '📍 Shared Location';
    if (type == 'audio') displaySummary = '🎤 Voice Message (${audioDurationSeconds}s)';

    // 1. Update / Create top-level conversation metadata: conversations/{conversationId}
    await _db.collection('conversations').doc(conversationId).set({
      'participants': [actualSenderUid, actualReceiverUid],
      'participantPhones': [normSenderPhone, normReceiverPhone],
      'lastMessage': displaySummary,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastTime': 'Just now',
      'lastSenderId': actualSenderUid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Add message to subcollection: conversations/{conversationId}/messages
    final msgData = {
      'senderId': actualSenderUid,
      'receiverId': actualReceiverUid,
      'senderPhone': normSenderPhone,
      'receiverPhone': normReceiverPhone,
      'text': text,
      'type': type,
      'mediaPath': mediaPath,
      'fileName': fileName,
      'fileSize': fileSize,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'locationAddress': locationAddress,
      'audioDurationSeconds': audioDurationSeconds,
      'time': 'Just now',
      'isDelivered': false,
      'isRead': false,
      'sentAt': FieldValue.serverTimestamp(),
      'deliveredAt': null,
      'readAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      'isEdited': false,
      'isDeleted': false,
      'deletedFor': [],
      'reactions': {},
    };

    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(msgData);
  }

  // Mark unread messages in a conversation as read (by recipient only)
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String recipientUid,
  }) async {
    try {
      final unreadQuery = await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: recipientUid)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadQuery.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in unreadQuery.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'isDelivered': true,
          'readAt': FieldValue.serverTimestamp(),
          'deliveredAt': doc.data()['deliveredAt'] ?? FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  // Live number of messages a user has not read yet in a conversation.
  //
  // This is what the green badge on each chat row is built from, so the count
  // updates the moment a new message arrives. Firestore cannot count without
  // downloading the documents, so the (small) set of unread messages is
  // streamed and counted on the client. Messages deleted for that user are not
  // counted.
  Stream<int> watchUnreadCount({
    required String conversationId,
    required String recipientUid,
  }) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: recipientUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.where((doc) {
              final deletedFor = doc.data()['deletedFor'] as List?;
              return !(deletedFor?.contains(recipientUid) ?? false);
            }).length);
  }

  // Mark undelivered messages as delivered when recipient device receives them
  Future<void> markMessagesAsDelivered({
    required String conversationId,
    required String recipientUid,
  }) async {
    try {
      final undeliveredQuery = await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: recipientUid)
          .where('isDelivered', isEqualTo: false)
          .get();

      if (undeliveredQuery.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in undeliveredQuery.docs) {
        batch.update(doc.reference, {
          'isDelivered': true,
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  // Edit Message (only by sender)
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete Message for Everyone (only by sender)
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': 'This message was deleted',
      'isDeleted': true,
      'mediaPath': '',
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete Message for Me (hides message for current caller)
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String uid,
  }) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([uid]),
    });
  }

  // Toggle Reaction on a Message
  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    final docRef = _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

    if (reactions[uid] == emoji) {
      reactions.remove(uid);
    } else {
      reactions[uid] = emoji;
    }

    await docRef.update({'reactions': reactions});
  }

  // Pin Message at Conversation level
  Future<void> pinMessage({
    required String conversationId,
    required String messageId,
    required String messageText,
  }) async {
    await _db.collection('conversations').doc(conversationId).set({
      'pinnedMessageId': messageId,
      'pinnedText': messageText,
      'pinnedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Unpin Message
  Future<void> unpinMessage({
    required String conversationId,
  }) async {
    await _db.collection('conversations').doc(conversationId).set({
      'pinnedMessageId': FieldValue.delete(),
      'pinnedText': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // Get real-time private conversations where current user is a participant
  Stream<QuerySnapshot> getPrivateConversationsStream([String? uid]) {
    final activeUid = uid ?? currentUid;
    return _db
        .collection('conversations')
        .where('participants', arrayContains: activeUid)
        .snapshots();
  }

  // Get real-time messages for a private conversation subcollection.
  //
  // Firestore snapshots streams are multi-subscription, but callers should
  // still hold on to ONE instance instead of rebuilding it in build(), which
  // would re-attach a Firestore listener on every rebuild.
  Stream<QuerySnapshot> getPrivateMessagesStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Real-time conversation metadata (pin, last message, disappearing timer).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConversationStream(
      String conversationId) {
    return _db.collection('conversations').doc(conversationId).snapshots();
  }

  // ─── CALL HISTORY ──────────────────────────────────────────────────────────
  //
  // Entries are stored in the top-level `calls` collection and identify both
  // participants by Firebase UID, so the same Firestore rules that protect
  // conversations also keep call history private.

  /// Record a call action between the logged-in user and another ModyChat user.
  Future<void> logCall({
    required String otherUid,
    bool isVideo = false,
    bool outgoing = true,
  }) async {
    final callerUid = currentUid;
    final calleeUid = otherUid.trim();
    if (callerUid.isEmpty || calleeUid.isEmpty || calleeUid == callerUid) {
      return;
    }

    String calleePhone = '';
    try {
      final profile = await getUserProfileById(calleeUid);
      calleePhone = profile?.phone ?? '';
    } catch (_) {}

    await _db.collection('calls').add({
      'participants': [callerUid, calleeUid],
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'callerPhone': normalizePhone(currentUserPhone),
      'calleePhone': normalizePhone(calleePhone),
      'type': isVideo ? 'video' : 'voice',
      'direction': outgoing ? 'outgoing' : 'incoming',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time call history for the logged-in user, newest first.
  /// Sorted on the client so no extra composite index is required.
  Stream<QuerySnapshot<Map<String, dynamic>>> getCallsStream([String? uid]) {
    final activeUid = uid ?? currentUid;
    return _db
        .collection('calls')
        .where('participants', arrayContains: activeUid)
        .snapshots();
  }

  // ─── USER PROFILE MANAGEMENT ───────────────────────────────────────────────

  Stream<DocumentSnapshot> getUserProfileStream(String identifier) {
    return _db.collection('users').doc(identifier).snapshots();
  }

  Future<DocumentSnapshot?> getUserProfile(String identifier) async {
    return _resolveUserDoc(identifier);
  }

  // Upload Profile Image to Supabase Storage bucket 'profiles' via REST API
  Future<String?> uploadProfileImageToSupabase(dynamic imageFile, String phone) async {
    const String supabaseUrl = 'https://lljoixgiomrmhvhyaiva.supabase.co';
    const String supabaseAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxsam9peGdpb21ybWh2aHlhaXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3OTEyNDMsImV4cCI6MjA4MTM2NzI0M30.Y5801BWzFoy41e3bqAFduFUowDzaIlCfnyfTZGWRRoI';
    const String bucket = 'profiles';

    try {
      final normPhone = normalizePhone(phone);
      final fileName = '$normPhone/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$supabaseUrl/storage/v1/object/$bucket/$fileName';

      List<int> bytes;
      if (imageFile is String) {
        bytes = await File(imageFile).readAsBytes();
      } else if (imageFile is File) {
        bytes = await imageFile.readAsBytes();
      } else {
        bytes = await imageFile.readAsBytes();
      }

      final uri = Uri.parse(path);
      await http.post(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'image/jpeg',
          'x-upsert': 'true',
        },
        body: bytes,
      );

      final publicUrl = '$supabaseUrl/storage/v1/object/public/$bucket/$fileName';
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  // ─── STAGE 3: BLOCK / UNBLOCK USER ─────────────────────────────────────────

  Future<void> blockUser(String blockedUid) async {
    final uid = currentUid;
    await _db.collection('users').doc(uid).collection('blocked').doc(blockedUid).set({
      'blockedAt': FieldValue.serverTimestamp(),
      'blockedUid': blockedUid,
    });
  }

  Future<void> unblockUser(String blockedUid) async {
    final uid = currentUid;
    await _db.collection('users').doc(uid).collection('blocked').doc(blockedUid).delete();
  }

  Future<bool> isUserBlocked(String targetUid) async {
    final uid = currentUid;
    final doc = await _db.collection('users').doc(uid).collection('blocked').doc(targetUid).get();
    return doc.exists;
  }

  Stream<bool> isUserBlockedStream(String targetUid) {
    final uid = currentUid;
    return _db
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // ─── STAGE 3: REPORT USER ───────────────────────────────────────────────────

  Future<void> reportUser({
    required String reportedUid,
    required String reason,
  }) async {
    await _db.collection('reports').add({
      'reporterId': currentUid,
      'reportedUserId': reportedUid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── STAGE 3: DISAPPEARING MESSAGES ─────────────────────────────────────────

  /// duration: 0=off, 24=24h, 168=7d, 720=30d (hours)
  Future<void> setDisappearingMessages({
    required String conversationId,
    required int durationHours,
  }) async {
    await _db.collection('conversations').doc(conversationId).set({
      'disappearingHours': durationHours,
      'disappearingUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<int> getDisappearingDurationStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0;
      return (doc.data()?['disappearingHours'] ?? 0) as int;
    });
  }

  // ─── STAGE 3: MY NOTES (Private Self-Conversation) ──────────────────────────

  String get myNotesConversationId => 'notes_$currentUid';

  Future<void> ensureMyNotesConversation() async {
    final convId = myNotesConversationId;
    final uid = currentUid;
    await _db.collection('conversations').doc(convId).set({
      'participants': [uid],
      'isNotes': true,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendNoteMessage({
    required String text,
    String type = 'text',
    String mediaPath = '',
    String fileName = '',
    String fileSize = '',
    int audioDurationSeconds = 0,
  }) async {
    final uid = currentUid;
    final convId = myNotesConversationId;
    await ensureMyNotesConversation();

    await _db.collection('conversations').doc(convId).collection('messages').add({
      'senderId': uid,
      'receiverId': uid,
      'text': text,
      'type': type,
      'mediaPath': mediaPath,
      'fileName': fileName,
      'fileSize': fileSize,
      'audioDurationSeconds': audioDurationSeconds,
      'time': 'Just now',
      'createdAt': FieldValue.serverTimestamp(),
      'isEdited': false,
      'isDeleted': false,
      'deletedFor': [],
      'reactions': {},
    });

    await _db.collection('conversations').doc(convId).set({
      'lastMessage': text.isNotEmpty ? text : '📎 Attachment',
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getMyNotesStream() {
    return _db
        .collection('conversations')
        .doc(myNotesConversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // ─── DATA MIGRATION UTILITY ────────────────────────────────────────────────

  /// Copy existing legacy messages/chats into the conversations structure.
  ///
  /// ADMIN ONLY. It writes messages on behalf of both participants, which the
  /// Firestore rules deliberately reject for client calls, so this must be run
  /// with admin credentials (or against the emulator), never from the app.
  Future<void> migrateLegacyMessagesToPrivateConversations() async {
    try {
      final chatsSnap = await _db.collection('chats').get();
      for (var chatDoc in chatsSnap.docs) {
        final data = chatDoc.data();
        final List<dynamic> legacyParticipants = data['participants'] ?? [];
        if (legacyParticipants.length < 2) continue;

        final phone1 = legacyParticipants[0].toString();
        final phone2 = legacyParticipants[1].toString();

        final uid1 = await getUidByPhone(phone1);
        final uid2 = await getUidByPhone(phone2);

        final conversationId = getConversationId(uid1, uid2);

        // Copy top-level metadata
        await _db.collection('conversations').doc(conversationId).set({
          'participants': [uid1, uid2],
          'participantPhones': [normalizePhone(phone1), normalizePhone(phone2)],
          'lastMessage': data['lastMessage'] ?? '',
          'lastTime': data['lastTime'] ?? 'Just now',
          'lastMessageAt': data['updatedAt'] ?? FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Copy subcollection messages
        final messagesSnap = await chatDoc.reference.collection('messages').get();
        for (var msgDoc in messagesSnap.docs) {
          final mData = msgDoc.data();
          final sPhone = (mData['senderPhone'] ?? '').toString();
          final rPhone = (mData['receiverPhone'] ?? '').toString();

          final senderUid = sPhone.isNotEmpty ? await getUidByPhone(sPhone) : uid1;
          final receiverUid = rPhone.isNotEmpty ? await getUidByPhone(rPhone) : uid2;

          await _db
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .doc(msgDoc.id)
              .set({
            ...mData,
            'senderId': senderUid,
            'receiverId': receiverUid,
            'createdAt': mData['timestamp'] ?? FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      // Migration logging
    }
  }
}
