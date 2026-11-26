import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile_model.dart';
import '../../services/firebase_service.dart';
import '../../services/image_cache_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  void _showSelectionModal(
    String title,
    String currentValue,
    List<String> options,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleText,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map((opt) => RadioListTile<String>(
                          title: Text(opt),
                          value: opt,
                          groupValue: currentValue,
                          fillColor: const WidgetStatePropertyAll(
                            AppColors.accentCoral,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              onSelected(val);
                              Navigator.pop(context);
                            }
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showBlockedContactsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final currentUid = _firebaseService.currentUid;

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Blocked Contacts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.accentCoral,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showBlockNewUserModal();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUid)
                        .collection('blocked')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentCoral,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No blocked contacts.',
                            style: TextStyle(color: AppColors.subtitleText),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final blockedUid = docs[index].id;

                          return FutureBuilder<UserProfile?>(
                            future: _firebaseService
                                .getUserProfileById(blockedUid),
                            builder: (context, profileSnap) {
                              final profile = profileSnap.data;
                              final name =
                                  profile?.displayName ?? blockedUid;
                              final phone = profile?.phone ?? '';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.avatarPeach,
                                  backgroundImage:
                                      (profile != null && profile.hasImage)
                                          ? CachedNetworkImageProvider(
                                              profile.imagePath)
                                          : null,
                                  child: (profile == null || !profile.hasImage)
                                      ? const Icon(
                                          Icons.person_off_rounded,
                                          color: AppColors.titleText,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  phone.isNotEmpty ? phone : blockedUid,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    await _firebaseService
                                        .unblockUser(blockedUid);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Unblocked $name'),
                                          backgroundColor: AppColors.darkNavy,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Unblock',
                                    style: TextStyle(
                                      color: AppColors.accentCoral,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBlockNewUserModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Select User to Block',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<UserProfile>>(
                    stream: _firebaseService.watchRegisteredUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentCoral,
                          ),
                        );
                      }

                      final users = (snapshot.data ?? [])
                          .where(
                            (u) => u.uid != _firebaseService.currentUid,
                          )
                          .toList();

                      if (users.isEmpty) {
                        return const Center(
                          child: Text(
                            'No users available to block',
                            style: TextStyle(color: AppColors.subtitleText),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.avatarPeach,
                                  backgroundImage: user.hasImage
                                      ? CachedNetworkImageProvider(
                                          user.imagePath)
                                      : null,
                              child: !user.hasImage
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.titleText,
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(user.phone),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _firebaseService.blockUser(user.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Blocked ${user.displayName}',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Block',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Scaffold(
      backgroundColor: AppColors.bodyBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Who can see my personal info',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accentCoral,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.access_time_filled_rounded,
                color: AppColors.darkNavy,
              ),
              title: const Text(
                'Last seen and online',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                settings.lastSeenOption,
                style: const TextStyle(color: AppColors.subtitleText),
              ),
              onTap: () => _showSelectionModal(
                'Last seen and online',
                settings.lastSeenOption,
                const ['Everyone', 'My Contacts', 'Nobody'],
                (val) => settings.setLastSeenOption(val),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.account_circle_rounded,
                color: AppColors.darkNavy,
              ),
              title: const Text(
                'Profile photo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                settings.profilePhotoOption,
                style: const TextStyle(color: AppColors.subtitleText),
              ),
              onTap: () => _showSelectionModal(
                'Profile photo visibility',
                settings.profilePhotoOption,
                const ['Everyone', 'My Contacts', 'Nobody'],
                (val) => settings.setProfilePhotoOption(val),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.darkNavy,
              ),
              title: const Text(
                'About info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                settings.aboutOption,
                style: const TextStyle(color: AppColors.subtitleText),
              ),
              onTap: () => _showSelectionModal(
                'About info visibility',
                settings.aboutOption,
                const ['Everyone', 'My Contacts', 'Nobody'],
                (val) => settings.setAboutOption(val),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: SwitchListTile(
              secondary: const Icon(
                Icons.done_all_rounded,
                color: AppColors.darkNavy,
              ),
              title: const Text(
                'Read Receipts',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'If turned off, you won\'t send or receive read receipts',
              ),
              value: settings.readReceipts,
              activeThumbColor: AppColors.accentCoral,
              onChanged: (val) => settings.setReadReceipts(val),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Disappearing Messages & Security',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accentCoral,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.timer_outlined,
                color: AppColors.darkNavy,
              ),
              title: const Text(
                'Default Message Timer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Start new chats with disappearing messages set to your timer',
              ),
              trailing: Text(
                settings.disappearingMessagesTimer,
                style: const TextStyle(color: AppColors.subtitleText),
              ),
              onTap: () => _showSelectionModal(
                'Disappearing Message Timer',
                settings.disappearingMessagesTimer,
                const ['Off', '24 Hours', '7 Days', '90 Days'],
                (val) => settings.setDisappearingMessagesTimer(val),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_firebaseService.currentUid)
                  .collection('blocked')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.red),
                  title: const Text(
                    'Blocked Contacts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$count blocked contacts'),
                  onTap: _showBlockedContactsModal,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

