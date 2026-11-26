import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe your problem or send feedback to our technical team:',
                style: TextStyle(fontSize: 13, color: AppColors.subtitleText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your message or issue details...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentCoral, width: 2),
                  ),
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
              onPressed: () {
                final text = _feedbackController.text.trim();
                Navigator.pop(context);
                if (text.isNotEmpty) {
                  _feedbackController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you! Your feedback has been sent to Modychat Support.'),
                      backgroundColor: AppColors.darkNavy,
                    ),
                  );
                }
              },
              child: const Text('Send', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAppInfoDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Modychat',
      applicationVersion: '1.0.0 (Build 2026)',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentCoral,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Modychat is a real-time messaging application designed for seamless connection, privacy, and user speed.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 8),
        const Text(
          '© 2026 ModyTech Inc. All rights reserved.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
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
          'Help & Feedback',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.help_center_rounded, color: AppColors.darkNavy),
              title: const Text('Help Center & FAQ', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Get help, troubleshoot issues & read FAQs'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (context) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            const ExpansionTile(
                              title: Text('How do I backup my messages?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Go to Settings > Chats & Wallpaper > Chat Backup to save your chat history.'),
                                ),
                              ],
                            ),
                            const ExpansionTile(
                              title: Text('Is my phone number visible to others?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('You can manage phone number visibility under Settings > Privacy > About info.'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.support_agent_rounded, color: AppColors.darkNavy),
              title: const Text('Contact Support / Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Questions? Reach out to our support team'),
              onTap: _showContactSupportDialog,
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_rounded, color: AppColors.darkNavy),
              title: const Text('Terms & Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Terms & Privacy Policy'),
                    content: const SingleChildScrollView(
                      child: Text(
                        'Modychat respects user data privacy. All messages sent between users are encrypted and synchronized using Firebase Firestore.\n\nBy using Modychat, you agree to our Terms of Service and Privacy Guidelines.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppColors.darkNavy),
              title: const Text('App Info', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Modychat v1.0.0 (Build 2026)'),
              onTap: _showAppInfoDialog,
            ),
          ),
        ],
      ),
    );
  }
}
