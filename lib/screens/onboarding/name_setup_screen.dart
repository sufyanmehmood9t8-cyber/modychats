import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/home_screen.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_colors.dart';

class NameSetupScreen extends StatefulWidget {
  final String phoneNumber;

  const NameSetupScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  bool _isSaving = false;
  String? _selectedImagePath;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
          _selectedImagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select image: $e')),
        );
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

  Future<void> _onFinishPressed() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: AppColors.accentCoral,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Upload profile image to Supabase if selected
      if (_selectedImagePath != null) {
        final uploaded = await _firebaseService.uploadProfileImageToSupabase(
          File(_selectedImagePath!),
          widget.phoneNumber,
        );
        if (uploaded != null && uploaded.isNotEmpty) {
          _uploadedImageUrl = uploaded;
        }
      }

      // 2. Save user profile to Firestore
      await _firebaseService.updateUserProfile(
        phone: widget.phoneNumber,
        name: name,
        profileImage: _uploadedImageUrl,
      );

      // 3. Set current active user in memory and persist onboarding status
      FirebaseService.setCurrentUser(widget.phoneNumber, name);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await prefs.setString('user_phone', widget.phoneNumber);
      await prefs.setString('user_name', name);

      if (mounted) {
        // 4. Push directly to HomeScreen clearing navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
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
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile Info',
                style: TextStyle(
                  color: AppColors.titleText,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please provide your name and an optional profile picture.',
                style: TextStyle(
                  color: AppColors.subtitleText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // Profile Avatar Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.avatarPeach,
                      backgroundImage: _selectedImagePath != null
                          ? FileImage(File(_selectedImagePath!)) as ImageProvider
                          : null,
                      child: _selectedImagePath == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 56,
                              color: AppColors.titleText,
                            )
                          : null,
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
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Name Input Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleText,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type your name here',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onFinishPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Finish & Start Chatting',
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
        ),
      ),
    );
  }
}
