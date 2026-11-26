import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../theme/app_colors.dart';
import 'chat_avatar.dart';

class ChatTile extends StatelessWidget {
  final ChatItemModel item;
  final VoidCallback? onTap;

  /// Live unread count. Falls back to the count stored on the item when null.
  final int? unreadCount;

  /// Color of the unread badge on the avatar.
  final Color badgeColor;

  const ChatTile({
    super.key,
    required this.item,
    this.onTap,
    this.unreadCount,
    this.badgeColor = const Color(0xFF2ECC71),
  });

  @override
  Widget build(BuildContext context) {
    final unseen = unreadCount ?? item.unreadCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              // Avatar with badge & image
              ChatAvatar(
                backgroundColor: item.avatarBgColor,
                avatarType: item.avatarType,
                unreadCount: unseen,
                imagePath: item.imagePath,
                badgeColor: badgeColor,
              ),

              const SizedBox(width: 16),

              // Title and Subtitle Preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: const TextStyle(
                        color: AppColors.titleText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.subtitleText,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Timestamp
              Text(
                item.time,
                style: const TextStyle(
                  color: AppColors.titleText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
