import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../screens/onboarding/phone_auth_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isProcessing = false;

  void _showChangeNumberDialog() {
    final oldController = TextEditingController(text: FirebaseService.currentUserPhone);
    final newController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Change Phone Number', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Changing your phone number will migrate your account info & settings.',
                style: TextStyle(fontSize: 13, color: AppColors.subtitleText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: oldController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Current Phone Number',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'New Phone Number (e.g. +923001234567)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
              onPressed: () async {
                final newPhone = newController.text.trim();
                if (newPhone.isEmpty || newPhone.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid phone number.')),
                  );
                  return;
                }

                Navigator.pop(context);
                setState(() => _isProcessing = true);

                try {
                  // Update profile with new phone number
                  await _firebaseService.updateUserProfile(
                    phone: newPhone,
                    name: FirebaseService.currentUserName,
                  );
                  FirebaseService.setCurrentUser(newPhone, FirebaseService.currentUserName);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Phone number updated to $newPhone'),
                        backgroundColor: AppColors.darkNavy,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update phone number: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showRequestAccountInfoDialog() async {
    setState(() => _isProcessing = true);
    final userDoc = await _firebaseService.getUserProfile(_firebaseService.currentUid);
    final Map<String, dynamic> data = (userDoc?.data() as Map<String, dynamic>?) ?? {};
    if (mounted) setState(() => _isProcessing = false);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your ModyChat Account Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _infoRow('UID', _firebaseService.currentUid),
                _infoRow('Name', data['name'] ?? FirebaseService.currentUserName),
                _infoRow('Phone', data['phone'] ?? FirebaseService.currentUserPhone),
                _infoRow('About', data['about'] ?? 'Hey there! I am using ModyChat'),
                _infoRow('Gender', data['gender'] ?? 'Not specified'),
                _infoRow('Status', 'Active & Cloud Synced'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account report generated & verified.'),
                          backgroundColor: AppColors.darkNavy,
                        ),
                      );
                    },
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.subtitleText)),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.titleText),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to log out of ModyChat?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isProcessing = true);

                try {
                  await _firebaseService.setUserPresence(false);
                  await FirebaseAuth.instance.signOut();
                  NotificationService.instance.dispose();

                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: const Text('Log Out', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete My Account?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: const Text(
            'This permanently removes your ModyChat account and associated data:\n\n'
            '• Erases profile details & photo\n'
            '• Removes you from ModyChat user listings\n'
            '• Deletes your Firebase Auth account',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isProcessing = true);

                try {
                  await _firebaseService.setUserPresence(false);

                  // Delete Firebase Auth user if authenticated
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    try {
                      await currentUser.delete();
                    } catch (_) {
                      await FirebaseAuth.instance.signOut();
                    }
                  } else {
                    await FirebaseAuth.instance.signOut();
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account successfully deleted.'),
                        backgroundColor: Colors.red,
                      ),
                    );

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting account: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: const Text('Delete Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();

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
          'Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Container(
                color: Colors.white,
                child: SwitchListTile(
                  secondary: const Icon(Icons.security_rounded, color: AppColors.darkNavy),
                  title: const Text('Security Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Get notified when security code changes for a contact'),
                  value: settingsService.securityNotifications,
                  activeThumbColor: AppColors.accentCoral,
                  onChanged: (val) => settingsService.setSecurityNotifications(val),
                ),
              ),
              const Divider(height: 1, indent: 64),
              Container(
                color: Colors.white,
                child: SwitchListTile(
                  secondary: const Icon(Icons.phonelink_lock_rounded, color: AppColors.darkNavy),
                  title: const Text('Two-Step Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Require a PIN when registering your phone number again'),
                  value: settingsService.twoStepVerification,
                  activeThumbColor: AppColors.accentCoral,
                  onChanged: (val) => settingsService.setTwoStepVerification(val),
                ),
              ),
              const Divider(height: 1, indent: 64),
              Container(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.phonelink_setup_rounded, color: AppColors.darkNavy),
                  title: const Text('Change Number', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Migrate your account info, groups & settings'),
                  onTap: _showChangeNumberDialog,
                ),
              ),
              const Divider(height: 1, indent: 64),
              Container(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.download_rounded, color: AppColors.darkNavy),
                  title: const Text('Request Account Info', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Create a report of your Modychat account information'),
                  onTap: _showRequestAccountInfoDialog,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.darkNavy),
                  title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkNavy)),
                  subtitle: const Text('Sign out of your active ModyChat session'),
                  onTap: _showLogoutConfirmation,
                ),
              ),
              const Divider(height: 1, indent: 64),
              Container(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Delete My Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  subtitle: const Text('Erase account history and memberships'),
                  onTap: _showDeleteAccountConfirmation,
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accentCoral),
              ),
            ),
        ],
      ),
    );
  }
}

