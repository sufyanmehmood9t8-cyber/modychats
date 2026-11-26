import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import '../services/image_cache_service.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  bool _isUploading = false;
  String? _selectedLocalImagePath;
  String _profileImageUrl = '';
  final String _phone = FirebaseService.currentUserPhone;
  String _displayName = FirebaseService.currentUserName;
  String _gender = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = _displayName;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final doc = await _firebaseService.getUserProfile(_firebaseService.currentUid);
    if (doc != null && doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _displayName = data['name'] ?? _displayName;
          _nameController.text = _displayName;
          _profileImageUrl = data['profile_image'] ?? data['imagePath'] ?? '';
          _aboutController.text = data['about'] ?? '';
          _gender = (data['gender'] ?? '').toString();
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (picked != null) {
        setState(() {
          _selectedLocalImagePath = picked.path;
          _isUploading = true;
        });

        // 1. Upload to Supabase Storage bucket 'profiles'
        final uploadedUrl = await _firebaseService.uploadProfileImageToSupabase(
          File(picked.path),
          _phone,
        );

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          _profileImageUrl = uploadedUrl;

          // 2. Save profile image URL to user's Firestore document
          await _firebaseService.updateUserProfile(
            phone: _phone,
            name: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : _displayName,
            profileImage: _profileImageUrl,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated successfully!'),
                backgroundColor: AppColors.accentCoral,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.accentCoral),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.darkNavy),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      await _firebaseService.updateUserProfile(
        phone: _phone,
        name: newName,
        profileImage: _profileImageUrl.isNotEmpty ? _profileImageUrl : null,
        about: _aboutController.text.trim().isNotEmpty ? _aboutController.text.trim() : null,
        gender: _gender.isNotEmpty ? _gender : null,
      );

      // Update active in-memory current user name
      FirebaseService.setCurrentUser(_phone, newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved!'),
            backgroundColor: AppColors.darkNavy,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

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
          'Profile',
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
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final serverImage = data['profile_image'] ?? data['imagePath'] ?? '';
            if (serverImage.isNotEmpty && _selectedLocalImagePath == null) {
              _profileImageUrl = serverImage;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // Profile Avatar Picker
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: AppColors.avatarPeach,
                        backgroundImage: _selectedLocalImagePath != null
                            ? FileImage(File(_selectedLocalImagePath!)) as ImageProvider
                                : (_profileImageUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        _profileImageUrl)
                                    : null),
                        child: (_selectedLocalImagePath == null && _profileImageUrl.isEmpty)
                            ? const Icon(
                                Icons.person_rounded,
                                size: 64,
                                color: AppColors.titleText,
                              )
                            : null,
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.accentCoral,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImagePickerSheet,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.accentCoral,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap camera icon to change profile photo',
                  style: TextStyle(color: AppColors.subtitleText, fontSize: 13),
                ),
                const SizedBox(height: 36),

                // Name Field
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: AppColors.accentCoral, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Your Name',
                            style: TextStyle(
                              color: AppColors.subtitleText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.titleText,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter your display name',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // About Field
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.accentCoral, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'About',
                            style: TextStyle(
                              color: AppColors.subtitleText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _aboutController,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.titleText,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Hey there! I am using ModyChat',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Gender Selector
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wc_rounded, color: AppColors.accentCoral, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Gender',
                            style: TextStyle(
                              color: AppColors.subtitleText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _GenderOption(
                              label: 'Male',
                              icon: Icons.male_rounded,
                              isSelected: _gender == 'Male',
                              onTap: () => setState(() => _gender = 'Male'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GenderOption(
                              label: 'Female',
                              icon: Icons.female_rounded,
                              isSelected: _gender == 'Female',
                              onTap: () => setState(() => _gender = 'Female'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Phone Field (Read-only)
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.phone_outlined, color: AppColors.darkNavy, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Phone Number',
                            style: TextStyle(
                              color: AppColors.subtitleText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _phone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.titleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This phone number is used for authentication and contact matching.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Save Profile Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.activeTabBg : AppColors.bodyBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.subtitleText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.titleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
