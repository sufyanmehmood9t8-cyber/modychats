import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  void _showRingtonePicker(String title, String current, List<String> tones, ValueChanged<String> onSelected) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: tones
            .map((t) => SimpleDialogOption(
                  onPressed: () {
                    onSelected(t);
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t),
                      if (t == current)
                        const Icon(Icons.check_rounded, color: AppColors.accentCoral, size: 18),
                    ],
                  ),
                ))
            .toList(),
      ),
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
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Container(
            color: Colors.white,
            child: SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded, color: AppColors.darkNavy),
              title: const Text('Conversation Tones', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Play sounds for incoming and outgoing messages'),
              value: settings.conversationTones,
              activeThumbColor: AppColors.accentCoral,
              onChanged: (val) => settings.setConversationTones(val),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentCoral, fontSize: 13)),
          ),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.music_note_rounded, color: AppColors.darkNavy),
              title: const Text('Notification Tone', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(settings.messageTone, style: const TextStyle(color: AppColors.subtitleText)),
              onTap: () => _showRingtonePicker(
                'Message Notification Tone',
                settings.messageTone,
                ['Default (Chime)', 'Subtle Bell', 'Soft Chirp', 'Classic Drop'],
                (t) => settings.setMessageTone(t),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.vibration_rounded, color: AppColors.darkNavy),
              title: const Text('Vibration', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(settings.vibrationLength, style: const TextStyle(color: AppColors.subtitleText)),
              onTap: () => _showRingtonePicker(
                'Vibration Pattern',
                settings.vibrationLength,
                ['Off', 'Default', 'Short', 'Long'],
                (t) => settings.setVibrationLength(t),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.darkNavy),
              title: const Text('High Priority Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Show previews of notifications at top of screen'),
              value: settings.highPriorityNotifications,
              activeThumbColor: AppColors.accentCoral,
              onChanged: (val) => settings.setHighPriorityNotifications(val),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Groups & Calls', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentCoral, fontSize: 13)),
          ),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.group_rounded, color: AppColors.darkNavy),
              title: const Text('Group Notification Tone', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(settings.groupTone, style: const TextStyle(color: AppColors.subtitleText)),
              onTap: () => _showRingtonePicker(
                'Group Notification Tone',
                settings.groupTone,
                ['Default (Pop)', 'Whistle', 'Harmonica', 'Echo Chime'],
                (t) => settings.setGroupTone(t),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.phone_in_talk_rounded, color: AppColors.darkNavy),
              title: const Text('Call Ringtone', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(settings.callRingtone, style: const TextStyle(color: AppColors.subtitleText)),
              onTap: () => _showRingtonePicker(
                'Call Ringtone',
                settings.callRingtone,
                ['Modychat Breeze', 'Classic Marimba', 'Digital Wave', 'Harmonic Harp'],
                (t) => settings.setCallRingtone(t),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

