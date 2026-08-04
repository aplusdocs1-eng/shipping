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
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Image.network(
                    AppTheme.logoUrl,
                    height: 36,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'ACJ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.border, height: 1),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
