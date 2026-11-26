import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';

class StorageDataScreen extends StatefulWidget {
  const StorageDataScreen({super.key});

  @override
  State<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends State<StorageDataScreen> {
  void _showMediaAutoDownloadDialog(SettingsService settings) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('When using mobile data', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Photos'),
                    value: settings.autoPhotosMobile,
                    activeColor: AppColors.accentCoral,
                    onChanged: (val) {
                      settings.setAutoPhotosMobile(val ?? false);
                      setDialogState(() {});
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Audio'),
                    value: settings.autoAudioMobile,
                    activeColor: AppColors.accentCoral,
                    onChanged: (val) {
                      settings.setAutoAudioMobile(val ?? false);
                      setDialogState(() {});
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Videos'),
                    value: settings.autoVideosMobile,
                    activeColor: AppColors.accentCoral,
                    onChanged: (val) {
                      settings.setAutoVideosMobile(val ?? false);
                      setDialogState(() {});
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Documents'),
                    value: settings.autoDocumentsMobile,
                    activeColor: AppColors.accentCoral,
                    onChanged: (val) {
                      settings.setAutoDocumentsMobile(val ?? false);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageStorageModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manage Storage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const ListTile(
                leading: Icon(Icons.image_rounded, color: AppColors.accentCoral),
                title: Text('Media Cache'),
                subtitle: Text('Photos, Videos & Voice Notes (~420 MB)'),
              ),
              const ListTile(
                leading: Icon(Icons.folder_zip_rounded, color: AppColors.darkNavy),
                title: Text('Document Cache'),
                subtitle: Text('PDFs & Shared Files (~120 MB)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.cleaning_services_rounded, color: Colors.white),
                  label: const Text('Clear Temporary Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Temporary media cache cleared successfully!'),
                        backgroundColor: AppColors.darkNavy,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNetworkUsageModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Network Usage Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const ListTile(
                leading: Icon(Icons.chat_bubble_rounded, color: AppColors.darkNavy),
                title: Text('Messages Sent / Received'),
                trailing: Text('1,420 / 3,890', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const ListTile(
                leading: Icon(Icons.cloud_upload_rounded, color: AppColors.accentCoral),
                title: Text('Total Data Sent'),
                trailing: Text('2.8 GB', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const ListTile(
                leading: Icon(Icons.cloud_download_rounded, color: AppColors.darkNavy),
                title: Text('Total Data Received'),
                trailing: Text('8.4 GB', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    final autoSummary = [
      if (settings.autoPhotosMobile) 'Photos',
      if (settings.autoAudioMobile) 'Audio',
      if (settings.autoVideosMobile) 'Videos',
      if (settings.autoDocumentsMobile) 'Documents',
    ];
    final autoText = autoSummary.isEmpty ? 'None' : autoSummary.join(', ');

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
          'Storage and Data',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Storage Usage Meter Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Storage Used', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('1.4 GB / 64 GB', style: TextStyle(color: AppColors.accentCoral, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.22,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCoral),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Includes 340 MB photos, 820 MB videos, 240 MB voice notes.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Network & Storage', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentCoral, fontSize: 13)),
          ),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.data_usage_rounded, color: AppColors.darkNavy),
              title: const Text('Manage Storage', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('1.4 GB used in chats & media'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showManageStorageModal,
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.swap_vert_circle_rounded, color: AppColors.darkNavy),
              title: const Text('Network Usage', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Sent: 2.8 GB • Received: 8.4 GB'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showNetworkUsageModal,
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: SwitchListTile(
              secondary: const Icon(Icons.data_saver_on_rounded, color: AppColors.darkNavy),
              title: const Text('Use less data for calls', style: TextStyle(fontWeight: FontWeight.bold)),
              value: settings.useLessDataForCalls,
              activeThumbColor: AppColors.accentCoral,
              onChanged: (val) => settings.setUseLessDataForCalls(val),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Media Auto-Download', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentCoral, fontSize: 13)),
          ),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.signal_cellular_alt_rounded, color: AppColors.darkNavy),
              title: const Text('When using mobile data', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(autoText),
              onTap: () => _showMediaAutoDownloadDialog(settings),
            ),
          ),
          const Divider(height: 1, indent: 64),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.wifi_rounded, color: AppColors.darkNavy),
              title: const Text('When connected on Wi-Fi', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('All media'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wi-Fi auto download: All Media Enabled')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

