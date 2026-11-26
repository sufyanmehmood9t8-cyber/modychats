import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_avatar.dart';
import 'chat_detail_screen.dart';

class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _openChat(UserProfile person) {
    final item = ChatItemModel(
      id: person.uid,
      name: person.name,
      customName: person.name,
      phone: person.phone,
      message: 'Tap to start conversation',
      time: 'Just now',
      unreadCount: 0,
      avatarBgColor: person.avatarBgColor,
      avatarType: person.avatarType,
      imagePath: person.imagePath,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        // The selected user's UID is the identity used by the chat screen.
        builder: (_) => ChatDetailScreen(contact: item, otherUserId: person.uid),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fixed "People" Header Row (same layout as the other tabs)
        Padding(
          padding:
              const EdgeInsets.only(left: 24, right: 24, top: 38, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'People',
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

        // Search Users Field
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.titleText,
              ),
              decoration: InputDecoration(
                hintText: 'Search people by name or phone',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.accentCoral,
                  size: 22,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.subtitleText,
                          size: 20,
                        ),
                      ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              ),
            ),
          ),
        ),

        // Real registered ModyChat users
        Expanded(
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnap) {
              final currentUser =
                  authSnap.data ?? FirebaseAuth.instance.currentUser;
              final currentUid = currentUser?.uid ?? _firebaseService.currentUid;
              final currentPhone = FirebaseService.currentUserPhone;

              if (currentUid.isEmpty || currentUid == 'unknown') {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<UserProfile>>(
                stream: _firebaseService.watchRegisteredUsers(),
                builder: (context, usersSnap) {
                  if (usersSnap.hasError) {
                    return _buildMessageState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load people',
                      message: 'Check your connection and try again.',
                      iconColor: AppColors.subtitleText,
                    );
                  }

                  if (!usersSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Any registered ModyChat user — no contact required.
                  final List<UserProfile> people = usersSnap.data!.where((p) {
                    if (p.uid.isEmpty || p.uid == currentUid) return false;
                    if (p.phone.isNotEmpty &&
                        FirebaseService.normalizePhone(p.phone) ==
                            FirebaseService.normalizePhone(currentPhone)) {
                      return false;
                    }
                    return p.name.trim().isNotEmpty;
                  }).toList()
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  final List<UserProfile> visible = _query.isEmpty
                      ? people
                      : people
                          .where((p) =>
                              p.name.toLowerCase().contains(_query) ||
                              p.phone.toLowerCase().contains(_query))
                          .toList();

                  if (visible.isEmpty) {
                    return _buildMessageState(
                      icon: _query.isEmpty
                          ? Icons.people_alt_rounded
                          : Icons.search_off_rounded,
                      title: _query.isEmpty
                          ? 'No People Yet'
                          : 'No Results Found',
                      message: _query.isEmpty
                          ? 'Registered ModyChat users will appear here. New users show up as soon as they finish signing up.'
                          : 'No one matches "$_query". Try a different name or phone number.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 32),
                    physics: const BouncingScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final person = visible[index];
                      return _buildPersonTile(context, person);
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

  Widget _buildPersonTile(BuildContext context, UserProfile person) {
    final subtitle = person.about.isNotEmpty ? person.about : person.phone;

    return InkWell(
      onTap: () => _openChat(person),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(
              backgroundColor: person.avatarBgColor,
              avatarType: person.avatarType,
              unreadCount: 0,
              imagePath: person.imagePath,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.titleText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (person.gender.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _GenderChip(gender: person.gender),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.subtitleText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ChatButton(onPressed: () => _openChat(person)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
    Color? iconColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.avatarPeach.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.accentCoral,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.titleText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.subtitleText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String gender;

  const _GenderChip({required this.gender});

  @override
  Widget build(BuildContext context) {
    final isFemale = gender == 'Female';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isFemale ? AppColors.avatarPink : AppColors.avatarTeal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFemale ? Icons.female_rounded : Icons.male_rounded,
            size: 12,
            color: isFemale ? const Color(0xFFC2185B) : const Color(0xFF00695C),
          ),
          const SizedBox(width: 3),
          Text(
            gender,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFemale ? const Color(0xFFC2185B) : const Color(0xFF00695C),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ChatButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentCoral,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.chat_bubble_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
