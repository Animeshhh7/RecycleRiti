import 'package:flutter/material.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/theme.dart';

class ProfileOptions extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfileOptions({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor, // Use consistent card color
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            _buildOptionItem(
              icon: Icons.star,
              iconColor: Colors.orange,
              title: "Rewards",
              onTap: () => Navigator.pushNamed(context, AppRoutes.rewards),
            ),
            _buildOptionItem(
              icon: Icons.schedule,
              iconColor: AppTheme.primaryColor,
              title: "Recycling History",
              onTap: () => Navigator.pushNamed(context, AppRoutes.recyclingHistory),
            ),
            _buildOptionItem(
              icon: Icons.event,
              iconColor: Colors.purple,
              title: "Events History",
              onTap: () => Navigator.pushNamed(context, AppRoutes.eventsHistory),
            ),
            _buildOptionItem(
              icon: Icons.settings,
              iconColor: AppTheme.secondaryTextColor,
              title: "Account Settings",
              onTap: () => Navigator.pushNamed(context, AppRoutes.accountSettings),
            ),
            _buildOptionItem(
              icon: Icons.help,
              iconColor: Colors.red,
              title: "Help & Support",
              onTap: () => Navigator.pushNamed(context, AppRoutes.helpSupport),
            ),
            Divider(height: 20, thickness: 1, color: AppTheme.secondaryTextColor.withOpacity(0.3), indent: 20, endIndent: 20),
            _buildOptionItem(
              icon: Icons.logout,
              title: "Logout",
              iconColor: Colors.redAccent,
              textColor: Colors.redAccent,
              onTap: onLogout,
              isLogout: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.blue,
    Color textColor = Colors.black,
    bool isLogout = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isLogout ? Colors.redAccent.withOpacity(0.1) : iconColor.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTheme.bodyTextStyle.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              isLogout ? Icons.logout : Icons.arrow_forward_ios,
              size: 16,
              color: isLogout ? Colors.redAccent : AppTheme.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}// 2476
// 29386
