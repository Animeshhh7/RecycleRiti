// lib/widgets/agent_drawer.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';

class AgentDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final String? agentUsername;
  final Map<String, dynamic>? agentDetails;

  const AgentDrawer({
    super.key,
    required this.onLogout,
    this.agentUsername,
    this.agentDetails,
  });

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.primaryColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTheme.bodyTextStyle.copyWith(
                  fontSize: 16,
                  color: color ?? AppTheme.textColor,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color ?? Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? profileImageUrl = agentDetails?['profileImage'] != null
        ? '${AuthService.baseUrl.replaceAll('/api', '')}${agentDetails!['profileImage']}?t=${DateTime.now().millisecondsSinceEpoch}'
        : null;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: const AlwaysStoppedAnimation(1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: profileImageUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: profileImageUrl,
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                      placeholder: (context, url) => const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                      errorWidget: (context, url, error) {
                                        print('Drawer: Error loading profile image - $error');
                                        return Icon(
                                          Icons.person,
                                          color: AppTheme.primaryColor,
                                          size: 40,
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    color: AppTheme.primaryColor,
                                    size: 40,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agentUsername ?? 'Agent',
                                style: AppTheme.sectionTitleStyle.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Agent',
                                style: AppTheme.bodyTextStyle.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          agentDetails?['phone']?.toString() ?? 'Phone not available',
                          style: AppTheme.bodyTextStyle.copyWith(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.email,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          agentDetails?['email']?.toString() ?? 'Email not available',
                          style: AppTheme.bodyTextStyle.copyWith(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.edit,
            title: 'Edit Profile',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.editProfile);
            },
          ),
          _buildDrawerItem(
            icon: Icons.star,
            title: 'Rewards',
            onTap: () {
              Navigator.pop(context);
              ExceptionHandling.showSnackBar(context, 'Rewards not implemented');
            },
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'Recycling History',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.recyclingHistory); // Updated to use recyclingHistory
            },
          ),
          _buildDrawerItem(
            icon: Icons.event,
            title: 'Events History',
            onTap: () {
              Navigator.pop(context);
              ExceptionHandling.showSnackBar(context, 'Events History not implemented');
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Account Settings',
            onTap: () {
              Navigator.pop(context);
              ExceptionHandling.showSnackBar(context, 'Account Settings not implemented');
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}// 3290
// 24869
// 24865
// 24256
// 8676
