import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_avatar.dart';
import 'call_screen.dart';

/// Call history list.
///
/// Every row is rendered from the shared `UserProfile` source (Firestore
/// `users`, keyed by Firebase UID), exactly like People, Chats and Status, so
/// a name or picture change is reflected here too.
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return Column(
      children: [
        // Fixed "All Calls" Header Row with Spacious Top Margin
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 38, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Calls',
                style: TextStyle(
                  color: AppColors.titleText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.titleText,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Scrollable Calls Content
        Expanded(
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnap) {
              final currentUser =
                  authSnap.data ?? FirebaseAuth.instance.currentUser;
              final currentUid = currentUser?.uid ?? firebaseService.currentUid;

              if (currentUid.isEmpty || currentUid == 'unknown') {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firebaseService.getCallsStream(currentUid),
                builder: (context, callsSnap) {
                  final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
                    ...?callsSnap.data?.docs,
                  ];

                  // Newest first. `createdAt` is a server timestamp, so it is
                  // null for a moment on the local write — fall back to the
                  // document id (creation time) while it resolves.
                  docs.sort((a, b) =>
                      _createdAtMs(b).compareTo(_createdAtMs(a)));

                  if (callsSnap.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Could not load your call history.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subtitleText),
                        ),
                      ),
                    );
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No recent calls',
                          style: TextStyle(
                            color: AppColors.titleText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ...docs.map((doc) {
                        final data = doc.data();
                        final participants = <String>[
                          ...?(data['participants'] as List?)?.cast<String>(),
                        ];
                        final otherUid = participants
                                .firstWhere((uid) => uid != currentUid,
                                    orElse: () => '')
                                .trim();

                        final isOutgoing =
                            (data['direction'] ?? 'outgoing') == 'outgoing';
                        final isVideo = (data['type'] ?? 'voice') == 'video';

                        return _buildCallItem(
                          context: context,
                          otherUid: otherUid,
                          firebaseService: firebaseService,
                          time: _formatCallTime(_createdAtMs(doc)),
                          isIncoming: !isOutgoing,
                          isVideo: isVideo,
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static int _createdAtMs(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final createdAt = doc.data()['createdAt'];
    if (createdAt is Timestamp) return createdAt.millisecondsSinceEpoch;
    final idTs = int.tryParse(doc.id.split('-').first);
    return idTs ?? 0;
  }

  static String _formatCallTime(int millis) {
    if (millis <= 0) return 'Just now';
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '$hh:$mm';
    }
    return '${time.day}/${time.month}/${time.year}, $hh:$mm';
  }

  Widget _buildCallItem({
    required BuildContext context,
    required String otherUid,
    required FirebaseService firebaseService,
    required String time,
    required bool isIncoming,
    required bool isVideo,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      // ONE profile stream per row (shared by the avatar and the name) so a
      // row never attaches two Firestore listeners to the same user.
      child: StreamBuilder<UserProfile>(
        stream: firebaseService.watchUserProfile(otherUid),
        builder: (context, profileSnap) {
          final profile = profileSnap.data ?? UserProfile(uid: otherUid);
          return Row(
            children: [
              // The other participant's current profile
              ChatAvatar(
                backgroundColor: profile.avatarBgColor,
                avatarType: profile.avatarType,
                unreadCount: 0,
                imagePath: profile.imagePath,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.titleText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isIncoming
                              ? Icons.call_received_rounded
                              : Icons.call_made_rounded,
                          color: isIncoming
                              ? Colors.green
                              : AppColors.accentCoral,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: const TextStyle(
                            color: AppColors.subtitleText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: otherUid.isEmpty
                    ? null
                    : () {
                        // Opens the real call screen; it creates the
                        // invitation, rings the other side and joins Agora.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              otherUserId: otherUid,
                              isVideo: isVideo,
                            ),
                          ),
                        );
                      },
                icon: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: AppColors.titleText,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
