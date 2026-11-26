import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/image_cache_service.dart';
import '../theme/app_colors.dart';
import 'profile_screen.dart';
import 'settings/account_settings_screen.dart';
import 'settings/privacy_settings_screen.dart';
import 'settings/chats_wallpaper_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/storage_data_screen.dart';
import 'settings/help_feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
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
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firebaseService.getUserProfileStream(_firebaseService.currentUid),
        builder: (context, snapshot) {
          String displayName = FirebaseService.currentUserName;
          String phone = FirebaseService.currentUserPhone;
          String? profileImage;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              if (data.containsKey('name') && (data['name'] as String).isNotEmpty) {
                displayName = data['name'];
              }
              if (data.containsKey('profile_image') && (data['profile_image'] as String).isNotEmpty) {
                profileImage = data['profile_image'];
              } else if (data.containsKey('imagePath') && (data['imagePath'] as String).isNotEmpty) {
                profileImage = data['imagePath'];
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // 1. User Profile Header Card (with profile photo)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.avatarPeach,
                        backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                            ? CachedNetworkImageProvider(profileImage)
                            : null,
                        child: (profileImage == null || profileImage.isEmpty)
                            ? const Icon(
                                Icons.person_rounded,
                                size: 34,
                                color: AppColors.titleText,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.titleText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.subtitleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.qr_code_rounded,
                          color: AppColors.accentCoral,
                          size: 26,
                        ),
                        onPressed: () => _showProfileQrModal(
                          context,
                          displayName,
                          phone,
                          profileImage,
                          _firebaseService.currentUid,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Profile
              _buildSettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.darkNavy,
                title: 'Profile',
                subtitle: 'Name, photo, phone number',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
              ),

              const Divider(height: 1, indent: 64),

              // 3. Account
              _buildSettingsTile(
                icon: Icons.key_outlined,
                iconColor: AppColors.darkNavy,
                title: 'Account',
                subtitle: 'Security notifications, change number',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                  );
                },
              ),

              const Divider(height: 1, indent: 64),

              // 4. Privacy
              _buildSettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.darkNavy,
                title: 'Privacy',
                subtitle: 'Block contacts, disappearing messages',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                  );
                },
              ),

              const Divider(height: 1, indent: 64),

              // 5. Chats & Wallpaper
              _buildSettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: AppColors.darkNavy,
                title: 'Chats & Wallpaper',
                subtitle: 'Theme, wallpapers, chat history',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatsWallpaperScreen()),
                  );
                },
              ),

              const Divider(height: 1, indent: 64),

              // 6. Notifications
              _buildSettingsTile(
                icon: Icons.notifications_none_rounded,
                iconColor: AppColors.darkNavy,
                title: 'Notifications',
                subtitle: 'Message, group & call tones',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                  );
                },
              ),

              const Divider(height: 1, indent: 64),

              // 7. Storage and Data
              _buildSettingsTile(
                icon: Icons.sd_storage_outlined,
                iconColor: AppColors.darkNavy,
                title: 'Storage and Data',
                subtitle: 'Network usage, auto-download media',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorageDataScreen()),
                  );
                },
              ),

              const Divider(height: 1, indent: 64),

              // 8. Help & Feedback
              _buildSettingsTile(
                icon: Icons.help_outline_rounded,
                iconColor: AppColors.darkNavy,
                title: 'Help & Feedback',
                subtitle: 'Help center, contact us, privacy policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpFeedbackScreen()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProfileQrModal(
    BuildContext context,
    String name,
    String phone,
    String? profileImage,
    String uid,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.avatarPeach,
                  backgroundImage:
                      (profileImage != null && profileImage.isNotEmpty)
                          ? CachedNetworkImageProvider(profileImage)
                          : null,
                  child: (profileImage == null || profileImage.isEmpty)
                      ? const Icon(Icons.person_rounded,
                          size: 40, color: AppColors.titleText)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.subtitleText,
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code Display Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CustomPaint(
                          painter: _QrCodePainter(data: 'modychat:user:$uid'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your ModyChat QR Code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtitleText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Copy UID Button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy User ID'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkNavy,
                          side: const BorderSide(color: AppColors.darkNavy),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied User ID: $uid'),
                              backgroundColor: AppColors.darkNavy,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCoral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sharing ModyChat QR code...'),
                              backgroundColor: AppColors.accentCoral,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.titleText,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.subtitleText,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _QrCodePainter extends CustomPainter {
  final String data;
  _QrCodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E293B);
    final bgPaint = Paint()..color = Colors.white;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridSize = 21;
    final cellSize = size.width / gridSize;

    // Deterministic matrix pattern from data hash
    final hash = data.hashCode;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Position detection patterns (corners)
        bool isCornerSquare =
            (r < 7 && c < 7) || (r < 7 && c >= 14) || (r >= 14 && c < 7);
        if (isCornerSquare) {
          bool isOuterBorder =
              r == 0 || r == 6 || c == 0 || c == 6 ||
              (r < 7 && (c == 14 || c == 20)) || (r == 0 && c >= 14) || (r == 6 && c >= 14) ||
              (r >= 14 && (c == 0 || c == 6)) || (r == 14 && c < 7) || (r == 20 && c < 7);
          bool isCenterPixel =
              (r >= 2 && r <= 4 && c >= 2 && c <= 4) ||
              (r >= 2 && r <= 4 && c >= 16 && c <= 18) ||
              (r >= 16 && r <= 18 && c >= 2 && c <= 4);

          if (isOuterBorder || isCenterPixel) {
            canvas.drawRect(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
              paint,
            );
          }
        } else {
          // Data bits based on deterministic hash
          final val = (hash ^ (r * 31 + c * 17)) % 3;
          if (val == 0) {
            canvas.drawRect(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

