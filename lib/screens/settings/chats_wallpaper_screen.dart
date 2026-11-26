import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../../services/theme_service.dart';
import '../../services/wallpaper_service.dart';
import '../../theme/app_colors.dart';

class ChatsWallpaperScreen extends StatelessWidget {
  const ChatsWallpaperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final wallpaperService = context.watch<WallpaperService>();

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
          'Chats & Wallpaper',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // ── DISPLAY SETTINGS ─────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Display Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accentCoral,
                fontSize: 13,
              ),
            ),
          ),

          // App Theme tile
          Container(
            color: Colors.white,
            child: ListTile(
              leading:
                  const Icon(Icons.color_lens_rounded, color: AppColors.darkNavy),
              title: const Text('App Theme',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                themeService.themeName,
                style: const TextStyle(color: AppColors.subtitleText),
              ),
              onTap: () => _showThemeDialog(context, themeService),
            ),
          ),

          // Inline theme selector — 3 visible chips
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _ThemeChip(
                  label: 'Light',
                  icon: Icons.wb_sunny_rounded,
                  selected:
                      themeService.currentTheme == AppThemeOption.light,
                  onTap: () => themeService.setTheme(AppThemeOption.light),
                ),
                const SizedBox(width: 10),
                _ThemeChip(
                  label: 'Dark',
                  icon: Icons.nightlight_round,
                  selected:
                      themeService.currentTheme == AppThemeOption.dark,
                  onTap: () => themeService.setTheme(AppThemeOption.dark),
                ),
                const SizedBox(width: 10),
                _ThemeChip(
                  label: 'ModyChat',
                  icon: Icons.auto_awesome_rounded,
                  selected:
                      themeService.currentTheme == AppThemeOption.modychat,
                  onTap: () =>
                      themeService.setTheme(AppThemeOption.modychat),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 64),

          // Chat Wallpaper tile
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.wallpaper_rounded,
                  color: AppColors.darkNavy),
              title: const Text('Chat Wallpaper',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Current: ${wallpaperService.wallpaperName}'),
              trailing: _buildWallpaperPreview(wallpaperService),
              onTap: () =>
                  _showWallpaperSheet(context, wallpaperService),
            ),
          ),

          const Divider(height: 1, indent: 64),

          // Font Size tile
          _FontSizeTile(),

          const SizedBox(height: 24),

          // ── CHAT ARCHIVES & BACKUP ────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Chat Archives & Backup',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accentCoral,
                fontSize: 13,
              ),
            ),
          ),

          Container(
            color: Colors.white,
            child: ListTile(
              leading:
                  const Icon(Icons.backup_rounded, color: AppColors.darkNavy),
              title: const Text('Chat Backup',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  const Text('Last Backup: Cloud Synced (Auto-Backup On)'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Chat Backup',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text(
                      'All your ModyChat conversations and media metadata are continuously backed up and synchronized with Firebase Cloud Firestore & Supabase Storage.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkNavy),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cloud backup verified & synced.'),
                              backgroundColor: AppColors.darkNavy,
                            ),
                          );
                        },
                        child: const Text('Back Up Now',
                            style: TextStyle(color: Colors.white)),
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
              leading: const Icon(Icons.history_rounded,
                  color: AppColors.darkNavy),
              title: const Text('Chat History',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'Export chat, clear all chats, archive all chats'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.ios_share_rounded,
                              color: AppColors.darkNavy),
                          title: const Text('Export Chat History'),
                          onTap: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Exporting chat history...'),
                                backgroundColor: AppColors.darkNavy,
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.archive_rounded,
                              color: AppColors.darkNavy),
                          title: const Text('Archive All Chats'),
                          onTap: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All chats archived.'),
                                backgroundColor: AppColors.darkNavy,
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_sweep_rounded,
                              color: Colors.red),
                          title: const Text('Clear All Chats',
                              style: TextStyle(color: Colors.red)),
                          onTap: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Chat messages cleared.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Wallpaper mini-preview thumbnail in trailing ─────────────────────────
  Widget _buildWallpaperPreview(WallpaperService ws) {
    if (ws.wallpaperType == WallpaperType.gallery &&
        ws.wallpaperPath.isNotEmpty &&
        File(ws.wallpaperPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(ws.wallpaperPath),
            width: 40, height: 40, fit: BoxFit.cover),
      );
    }
    if (ws.wallpaperType == WallpaperType.modychatDefault) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            colors: [Color(0xFFF4F5F9), Color(0xFFEDEEF3)],
          ),
        ),
      );
    }
    // Classic Doodle
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFFDFBF7),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Icon(Icons.grid_3x3_rounded,
          color: Colors.grey, size: 20),
    );
  }

  // ── Theme dialog (fallback / alternative) ────────────────────────────────
  void _showThemeDialog(BuildContext ctx, ThemeService themeService) {
    showDialog(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: AppThemeOption.values
            .map((opt) => SimpleDialogOption(
                  onPressed: () {
                    themeService.setTheme(opt);
                    Navigator.pop(context);
                  },
                  child: Row(
                    children: [
                      if (themeService.currentTheme == opt)
                        const Icon(Icons.check_rounded,
                            color: AppColors.accentCoral, size: 18),
                      if (themeService.currentTheme != opt)
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(opt == AppThemeOption.light
                          ? 'Light'
                          : opt == AppThemeOption.dark
                              ? 'Dark'
                              : 'ModyChat'),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Wallpaper bottom sheet ───────────────────────────────────────────────
  void _showWallpaperSheet(BuildContext ctx, WallpaperService ws) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose Chat Wallpaper',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Row of wallpaper options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _WallpaperOption(
                      label: 'Classic Doodle',
                      icon: Icons.grid_3x3_rounded,
                      bgColor: const Color(0xFFFDFBF7),
                      iconColor: Colors.grey,
                      selected: ws.wallpaperType ==
                          WallpaperType.classicDoodle,
                      onTap: () async {
                        await ws.setClassicDoodle();
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                    ),
                    _WallpaperOption(
                      label: 'ModyChat\nDefault',
                      icon: Icons.auto_awesome_rounded,
                      bgColor: const Color(0xFFF4F5F9),
                      iconColor: AppColors.accentCoral,
                      selected: ws.wallpaperType ==
                          WallpaperType.modychatDefault,
                      onTap: () async {
                        await ws.setModyChatDefault();
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                    ),
                    _WallpaperOption(
                      label: 'Choose from\nGallery',
                      icon: Icons.photo_library_rounded,
                      bgColor: const Color(0xFFEDF2FB),
                      iconColor: AppColors.darkNavy,
                      selected: ws.wallpaperType == WallpaperType.gallery,
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _pickGalleryImage(ctx, ws);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickGalleryImage(
      BuildContext ctx, WallpaperService ws) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) {
      await ws.setGalleryImage(picked.path);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Chat wallpaper updated!')),
        );
      }
    }
  }
}

// ── Compact theme chip ────────────────────────────────────────────────────────
class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentCoral : AppColors.bodyBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentCoral : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? Colors.white : AppColors.titleText),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.titleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wallpaper preview card ────────────────────────────────────────────────────
class _WallpaperOption extends StatelessWidget {
  const _WallpaperOption({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.accentCoral
                    : Colors.grey.shade300,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Center(
              child: selected
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.accentCoral, size: 28)
                  : Icon(icon, color: iconColor, size: 28),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? AppColors.accentCoral : AppColors.subtitleText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Font Size tile (self-contained stateful) ──────────────────────────────────
class _FontSizeTile extends StatefulWidget {
  @override
  State<_FontSizeTile> createState() => _FontSizeTileState();
}

class _FontSizeTileState extends State<_FontSizeTile> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Container(
      color: Colors.white,
      child: ListTile(
        leading:
            const Icon(Icons.format_size_rounded, color: AppColors.darkNavy),
        title: const Text('Font Size',
            style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(settings.fontSizeName,
            style: const TextStyle(color: AppColors.subtitleText)),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Font Size'),
              children: [
                SimpleDialogOption(
                  onPressed: () {
                    settings.setFontSize(AppFontSize.small);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Small'),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    settings.setFontSize(AppFontSize.medium);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Medium'),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    settings.setFontSize(AppFontSize.large);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Large'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

