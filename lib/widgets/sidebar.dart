import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'video_backdrop.dart';

// Navigation index map (matches _screens list in main.dart):
// 0  Home (Dashboard)
// 1  Packages
// 2  Pre-Alerts
// 3  Shipments
// 4  Customers
// 5  Invoices
// 6  POS
// 7  Labels
// 8  Manifest
// 9  Reports
// 10 Staff
// 11 Branches
// 12 Settings
// 13 Warehouse
// 14 Shipping Partners
// 15 Site Content
// 16 Accounting
// 17 Payroll

class AppNavDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppNavDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // Solid fallback: shows correctly on its own if the video is still
      // loading or fails outright — the video below is a bonus layer on
      // top of an already-complete, already-correct dark sidebar, not a
      // replacement it depends on.
      backgroundColor: AppTheme.sidebarBg,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: VideoBackdrop(
                enabled: true,
                assetPath: 'assets/videos/hero_background.mp4',
                fallback: const ColoredBox(color: AppTheme.sidebarBg),
              ),
            ),
          ),
          // Same "subtle everywhere" scrim strength as the main body
          // backdrop, just tinted to the sidebar's own dark color instead
          // of the page's light one — nav text stays exactly as readable
          // as it was against the old solid sidebarBg.
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xE6171519),
            ), // AppTheme.sidebarBg @ ~90% alpha
          ),
          _DrawerContent(
            selectedIndex: selectedIndex,
            onItemSelected: onItemSelected,
          ),
        ],
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  const _DrawerContent({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo header — transparent so the video backdrop behind the
          // whole drawer shows through here too, not just below it.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/one_village_logo.png',
                  height: 36,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      'OV',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.sidebarActive,
                      ),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    size: 22,
                    color: AppTheme.sidebarText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _DrawerTile(
                  label: 'Home',
                  index: 0,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Accounting',
                  index: 16,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Packages',
                  index: 1,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Shipments',
                  index: 3,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Noticeboard',
                  index: 2,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Package request',
                  index: 7,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Warehouse',
                  index: 13,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Shipping Partners',
                  index: 14,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    color: AppTheme.border.withValues(alpha: 0.35),
                    height: 1,
                  ),
                ),
                _DrawerTile(
                  label: 'Customers',
                  index: 4,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Invoices',
                  index: 5,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'POS',
                  index: 6,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    color: AppTheme.border.withValues(alpha: 0.35),
                    height: 1,
                  ),
                ),
                _DrawerTile(
                  label: 'Manifest',
                  index: 8,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Reports',
                  index: 9,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Staff',
                  index: 10,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Payroll',
                  index: 17,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Branches',
                  index: 11,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Settings',
                  index: 12,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
                _DrawerTile(
                  label: 'Site Content',
                  index: 15,
                  selectedIndex: selectedIndex,
                  onTap: (i) {
                    onItemSelected(i);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _DrawerTile({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          // Sidebar-local accent (blush pink on the dark panel) rather
          // than the global AppTheme.primary (soft black) used for
          // selection everywhere else — primary would be invisible here.
          hoverColor: AppTheme.sidebarActive.withValues(alpha: 0.06),
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.sidebarActive.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: isSelected ? AppTheme.gold : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppTheme.sidebarActive
                    : AppTheme.sidebarText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
