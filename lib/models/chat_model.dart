import 'package:flutter/material.dart';

enum AvatarType {
  personMale,
  personFemale,
  personBeard,
  groupHandsUp,
  groupTeam,
}

class ChatItemModel {
  final String id;
  final String name;
  final String message;
  final String time;
  final int unreadCount;
  final Color avatarBgColor;
  final AvatarType avatarType;
  final String imagePath;
  final String phone;
  final String customName;

  const ChatItemModel({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.unreadCount,
    required this.avatarBgColor,
    required this.avatarType,
    this.imagePath = '',
    this.phone = '',
    this.customName = '',
  });

  /// WhatsApp-style name display:
  /// Uses custom local name if saved, otherwise falls back to phone number or name.
  String get displayName {
    if (customName.trim().isNotEmpty) return customName;
    if (phone.trim().isNotEmpty) return phone;
    return name;
  }
}

