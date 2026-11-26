import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_tile.dart';
import 'chat_detail_screen.dart';

class ChatsTab extends StatefulWidget {
  final VoidCallback? onBrowsePeople;

  const ChatsTab({super.key, this.onBrowsePeople});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

/// A chat row: the contact/chat item plus the conversation document it belongs
/// to, which is what the unread badge is counted from.
/// Small branded loader, placed below "All Chats" and above "Recent Chats".
/// The loading state is derived from a local StreamBuilder's connectionState
/// so this widget never calls setState during the parent build.
class _ChatsLoader extends StatelessWidget {
  final Animation<double> loadingAnimation;
  final FirebaseService firebaseService;

  const _ChatsLoader({
    required this.loadingAnimation,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? firebaseService.currentUid;

    return StreamBuilder<QuerySnapshot>(
      stream: currentUid.isNotEmpty && currentUid != 'unknown'
          ? firebaseService.getPrivateConversationsStream(currentUid)
          : null,
      builder: (context, chatsSnapshot) {
        final isWaiting = chatsSnapshot.connectionState == ConnectionState.waiting;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: isWaiting
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Container(
                    width: 140,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.darkNavy.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedBuilder(
                        animation: loadingAnimation,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            alignment: Alignment(loadingAnimation.value, 0),
                            widthFactor: 0.25,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4D9DE0),
                                    Color(0xFF7C4DFF),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4D9DE0)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// A chat row: the contact/chat item plus the conversation document it belongs
/// to, which is what the unread badge is counted from.
class _ChatRow {
  final String conversationId;
  final ChatItemModel item;

  const _ChatRow(this.conversationId, this.item);
}

class _ChatsTabState extends State<ChatsTab>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();

  /// One unread-count stream PER conversation, created once and reused.
  final Map<String, Stream<int>> _unreadStreams = {};

  late final AnimationController _loadingController;
  late final Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat();
    _loadingAnimation = Tween<double>(
      begin: -0.25,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Stream<int> _unreadCountStream(String conversationId, String recipientUid) {
    return _unreadStreams.putIfAbsent(
      '$conversationId|$recipientUid',
      () => _firebaseService.watchUnreadCount(
        conversationId: conversationId,
        recipientUid: recipientUid,
      ),
    );
  }

  void _openChatDetail(BuildContext context, ChatItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(contact: item, otherUserId: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ModyChat branded loader below All Chats, above Recent Chats
        _ChatsLoader(
          loadingAnimation: _loadingAnimation,
          firebaseService: _firebaseService,
        ),

        // Fixed "All Chats" Header Row with Filter Icon
        Padding(
          padding:
              const EdgeInsets.only(left: 24, right: 24, top: 38, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Chats',
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

        // Use StreamBuilder on Firebase Auth state to always get the latest UID
        Expanded(
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnap) {
              final currentUser = authSnap.data ?? FirebaseAuth.instance.currentUser;
              final currentUid = currentUser?.uid ?? _firebaseService.currentUid;

              if (currentUid.isEmpty || currentUid == 'unknown') {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<UserProfile>>(
                stream: _firebaseService.watchRegisteredUsers(),
                builder: (context, profilesSnap) {
                  // Live profile index by UID and by normalized phone.
                  final Map<String, UserProfile> profilesByUid = {};
                  final Map<String, UserProfile> profilesByPhone = {};
                  for (final p in profilesSnap.data ?? const <UserProfile>[]) {
                    if (p.uid.isNotEmpty) profilesByUid[p.uid] = p;
                    if (p.phone.isNotEmpty) {
                      profilesByPhone[
                          FirebaseService.normalizePhone(p.phone)] = p;
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _firebaseService.getPrivateConversationsStream(currentUid),
                    builder: (context, chatsSnapshot) {
                      final chatDocs = chatsSnapshot.data?.docs ?? [];

                      List<_ChatRow> chatList = [];

                      for (var doc in chatDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final List<dynamic> participants = data['participants'] ?? [];
                        final List<dynamic> participantPhones =
                            data['participantPhones'] ?? [];

                        // Skip My Notes conversations (single participant)
                        if (participants.length < 2) continue;

                        // Find the other user's UID
                        final List<String> participantUids = participants
                            .map((p) => p.toString())
                            .toList();
                        final otherIndex =
                            participantUids.indexOf(currentUid) == 0
                                ? 1
                                : 0;
                        final String otherId = participantUids.length > otherIndex
                            ? participantUids[otherIndex]
                            : '';
                        if (otherId.isEmpty || otherId == currentUid) continue;

                        // participantPhones is stored in the same order as
                        // participants, so use the matching index. Older
                        // conversations may not have a usable value, in which
                        // case the profile lookup by UID is the only source.
                        String otherPhone = '';
                        if (participantPhones.length > otherIndex) {
                          otherPhone =
                              participantPhones[otherIndex].toString().trim();
                        }

                        // Latest profile from the shared profile source
                        final UserProfile? profile = profilesByUid[otherId] ??
                            (otherPhone.isNotEmpty
                                ? profilesByPhone[
                                    FirebaseService.normalizePhone(otherPhone)]
                                : null);

                        final displayName = profile?.displayName ??
                            (otherPhone.isNotEmpty ? otherPhone : otherId);
                        final imagePath = profile?.imagePath ?? '';

                        chatList.add(
                          _ChatRow(
                            doc.id,
                            ChatItemModel(
                            id: otherId,
                            name: displayName,
                            customName: profile?.name ?? '',
                            phone: profile?.phone ?? otherPhone,
                            message: data['lastMessage'] ??
                                'Tap to start conversation',
                            time: data['lastTime'] ?? 'Just now',
                            unreadCount: 0,
                            avatarBgColor:
                                profile?.avatarBgColor ?? AppColors.avatarPeach,
                            avatarType:
                                profile?.avatarType ?? AvatarType.personMale,
                            imagePath: imagePath,
                          ),
                          ),
                        );
                      }

                      if (chatList.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppColors.avatarPeach
                                        .withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.forum_rounded,
                                    color: AppColors.accentCoral,
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'No Chats Yet',
                                  style: TextStyle(
                                    color: AppColors.titleText,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Your chat list is empty. Open People, pick any ModyChat user and press Chat to start a private conversation.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.subtitleText,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: widget.onBrowsePeople,
                                  icon: const Icon(Icons.people_alt_rounded,
                                      color: Colors.white),
                                  label: const Text(
                                    'Browse People',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentCoral,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.only(top: 4, bottom: 90),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 4),
                            child: Text(
                              'Recent Chats',
                              style: TextStyle(
                                color: AppColors.subtitleText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...chatList.map(
                            (row) => StreamBuilder<int>(
                              stream: _unreadCountStream(
                                  row.conversationId, currentUid),
                              builder: (context, unreadSnap) {
                                return ChatTile(
                                  item: row.item,
                                  unreadCount: unreadSnap.data ?? 0,
                                  onTap: () => _openChatDetail(context, row.item),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
