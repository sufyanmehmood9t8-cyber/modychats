import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/supabase_storage_service.dart';
import '../theme/app_colors.dart';
import 'chat_model.dart';

/// Single shared ModyChat user-profile model.
///
/// Every surface (People, Chat header, Status, Chats list, Profile) renders
/// profiles from this model, which is always built from the Firestore
/// `users` collection keyed by the real Firebase Auth UID.
class UserProfile {
  final String uid;
  final String name;
  final String phone;
  final String about;
  final String gender;
  final String imagePath;
  final bool isOnline;
  final dynamic lastSeen;

  const UserProfile({
    required this.uid,
    this.name = '',
    this.phone = '',
    this.about = '',
    this.gender = '',
    this.imagePath = '',
    this.isOnline = false,
    this.lastSeen,
  });

  static const UserProfile empty = UserProfile(uid: '');

  bool get hasImage => imagePath.trim().isNotEmpty;

  bool get isFemale => gender == 'Female';

  AvatarType get avatarType =>
      isFemale ? AvatarType.personFemale : AvatarType.personMale;

  Color get avatarBgColor =>
      isFemale ? AppColors.avatarPink : AppColors.avatarPeach;

  /// Best-effort display label: profile name, then phone, then UID.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (phone.trim().isNotEmpty) return phone.trim();
    return uid;
  }

  static String parseGender(dynamic raw) {
    final value = raw.toString().trim().toLowerCase();
    if (value == 'male' || value == 'm' || value == 'man') return 'Male';
    if (value == 'female' || value == 'f' || value == 'woman') return 'Female';
    return '';
  }

  factory UserProfile.fromFirestoreData(
    Map<String, dynamic>? data, {
    String docId = '',
  }) {
    final map = data ?? const <String, dynamic>{};
    final uid = (map['uid'] ?? '').toString().trim();
    return UserProfile(
      uid: uid.isNotEmpty ? uid : docId.trim(),
      name: (map['name'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      about: (map['about'] ?? '').toString().trim(),
      gender: parseGender(map['gender']),
      // Legacy rows may hold a bare Supabase storage path instead of a URL.
      imagePath: SupabaseStorageService.resolveMediaUrl(
        (map['profile_image'] ?? map['imagePath'] ?? '').toString(),
      ),
      isOnline: map['isOnline'] == true,
      lastSeen: map['lastSeen'],
    );
  }

  factory UserProfile.fromDocument(DocumentSnapshot doc) {
    return UserProfile.fromFirestoreData(
      doc.data() as Map<String, dynamic>?,
      docId: doc.id,
    );
  }

  UserProfile copyWith({
    String? uid,
    String? name,
    String? phone,
    String? about,
    String? gender,
    String? imagePath,
    bool? isOnline,
    dynamic lastSeen,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      gender: gender ?? this.gender,
      imagePath: imagePath ?? this.imagePath,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Merges two snapshots of the same user, preferring non-empty values.
  /// The `users` collection stores each profile twice (users/{uid} and
  /// users/{normalizedPhone}) so a merge keeps the freshest data.
  UserProfile mergeWith(UserProfile other) {
    if (other.uid.isEmpty) return this;
    return UserProfile(
      uid: uid.isNotEmpty ? uid : other.uid,
      name: _prefer(name, other.name),
      phone: _prefer(phone, other.phone),
      about: _prefer(about, other.about),
      gender: _prefer(gender, other.gender),
      imagePath: _prefer(imagePath, other.imagePath),
      isOnline: isOnline || other.isOnline,
      lastSeen: lastSeen ?? other.lastSeen,
    );
  }

  static String _prefer(String a, String b) {
    return a.trim().isNotEmpty ? a : b;
  }
}
