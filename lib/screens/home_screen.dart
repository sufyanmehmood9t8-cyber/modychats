import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/curved_header_clipper.dart';
import '../widgets/custom_tab_bar.dart';
import 'chats_tab.dart';
import 'calls_tab.dart';
import 'status_tab.dart';
import 'people_tab.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToPeopleTab() {
    _onTabSelected(3);
  }

  void _openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bodyBackground,
      body: Stack(
        children: [
          // 1. Organic Curved Dark Navy Header Backdrop Container
          ClipPath(
            clipper: HeaderClipper(),
            child: Container(
              height: 220,
              width: double.infinity,
              color: AppColors.darkNavy,
            ),
          ),

          // 2. Main Safe Area Top Controls & Tab Pages
          SafeArea(
            child: Column(
              children: [
                // Top App Bar Header (Camera Icon, Title "Modychat", Search Icon & Setting Icon)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Camera opened')),
                          );
                        },
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Text(
                        'Modychat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Search chats...')),
                              );
                            },
                            icon: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: _openSettingsScreen,
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Custom Pill Tab Bar (Chats, Status, Calls, People)
                CustomTabBar(
                  selectedIndex: _selectedTabIndex,
                  onTabSelected: _onTabSelected,
                ),

                const SizedBox(height: 8),

                // Tab Views PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                    children: [
                      ChatsTab(onBrowsePeople: _goToPeopleTab),
                      const StatusTab(),
                      const CallsTab(),
                      const PeopleTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Action Button (ONLY ON CHATS TAB)
        ],
      ),
    );
  }
}
