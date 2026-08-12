import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
      backgroundColor: AppTheme.sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo header — the palette's signature soft blush/lavender
            // gradient, matching the identity banner atop the app bar, so
            // the sidebar reads as part of the same brand surface rather
            // than a plain white panel bolted on beside it.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
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
                          color: AppTheme.textPrimary,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22, color: AppTheme.textPrimary),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppTheme.border, height: 1),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppTheme.border, height: 1),
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
          hoverColor: AppTheme.primary.withValues(alpha: 0.04),
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
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
                color: isSelected ? AppTheme.primary : AppTheme.sidebarText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
