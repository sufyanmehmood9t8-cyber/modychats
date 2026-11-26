import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../services/image_cache_service.dart';
import '../theme/app_colors.dart';

class ChatAvatar extends StatelessWidget {
  final Color backgroundColor;
  final AvatarType avatarType;
  final int unreadCount;
  final double size;
  final String imagePath;
  final Color badgeColor;

  const ChatAvatar({
    super.key,
    required this.backgroundColor,
    required this.avatarType,
    required this.unreadCount,
    this.size = 54.0,
    this.imagePath = '',
    this.badgeColor = AppColors.accentCoral,
  });

  @override
  Widget build(BuildContext context) {
    final isNetworkImage = imagePath.startsWith('http://') || imagePath.startsWith('https://');
    final isFileImage = !isNetworkImage && imagePath.isNotEmpty && File(imagePath).existsSync();
    final hasImage = isNetworkImage || isFileImage;

    ImageProvider? imageProvider;
    if (isNetworkImage) {
      imageProvider = CachedNetworkImageProvider(imagePath);
    } else if (isFileImage) {
      imageProvider = FileImage(File(imagePath));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Squircle / Rounded Square Avatar Container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            image: hasImage && imageProvider != null
                ? DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !hasImage
              ? Center(
                  child: _buildAvatarGraphic(avatarType),
                )
              : null,
        ),

        // Unread Notification Badge Overlay
        if (unreadCount > 0)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.bodyBackground,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Center(
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarGraphic(AvatarType type) {
    switch (type) {
      case AvatarType.personMale:
        return const Icon(
          Icons.face_retouching_natural_rounded,
          color: Color(0xFFD84315),
          size: 32,
        );
      case AvatarType.personFemale:
        return const Icon(
          Icons.face_3_rounded,
          color: Color(0xFFC2185B),
          size: 32,
        );
      case AvatarType.personBeard:
        return const Icon(
          Icons.face_6_rounded,
          color: Color(0xFF37474F),
          size: 32,
        );
      case AvatarType.groupHandsUp:
        return const Icon(
          Icons.thumb_up_alt_rounded,
          color: Color(0xFF5E35B1),
          size: 28,
        );
      case AvatarType.groupTeam:
        return const Icon(
          Icons.groups_rounded,
          color: Color(0xFF00838F),
          size: 30,
        );
    }
  }
}
