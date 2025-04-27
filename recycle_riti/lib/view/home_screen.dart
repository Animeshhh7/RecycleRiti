// lib/view/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/routes/routes.dart'; // Added for named route
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _currentRewardIndex = 0;

  final PageController _firstSliderController = PageController();
  final PageController _rewardsSliderController = PageController();

  final List<String> firstSliderImages = [
    'assets/images/slide1.jpg',
    'assets/images/slide2.jpg',
  ];

  final List<String> rewardsSliderImages = [
    'assets/images/rewards1.jpg',
    'assets/images/rewards2.png',
  ];

  Timer? _firstSliderTimer;
  Timer? _rewardsSliderTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _username;
  String? _profileImageUrl;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fetchUserProfile();

    _firstSliderController.addListener(() {
      final int page = _firstSliderController.page?.round() ?? 0;
      if (_currentIndex != page) {
        setState(() {
          _currentIndex = page;
        });
      }
    });

    _rewardsSliderController.addListener(() {
      final int page = _rewardsSliderController.page?.round() ?? 0;
      if (_currentRewardIndex != page) {
        setState(() {
          _currentRewardIndex = page;
        });
      }
    });

    // Initialize notifications with a callback to refresh the UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {}); // Refresh the UI when a notification is received
        },
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoSlide(
        _firstSliderController,
        firstSliderImages.length,
        (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      );
      _startAutoSlide(
        _rewardsSliderController,
        rewardsSliderImages.length,
        (index) {
          setState(() {
            _currentRewardIndex = index;
          });
        },
      );
      _animationController.forward();
    });
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.getUserProfile(),
      defaultErrorMessage: 'Failed to fetch profile',
      onSuccess: (response) {
        if (response['success']) {
          setState(() {
            _username = response['user']['username'] ?? 'User';
            _userRole = response['user']['role']?.toString().toLowerCase();
            String? profileImagePath = response['user']['profileImage'];
            if (profileImagePath != null) {
              profileImagePath = profileImagePath.replaceFirst('/uploads/', '');
              _profileImageUrl =
                  '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$profileImagePath?t=${DateTime.now().millisecondsSinceEpoch}';
            } else {
              _profileImageUrl = null;
            }
          });
        } else {
          throw Exception(response['message'] ?? 'Failed to fetch profile');
        }
      },
      onError: (error) {
        setState(() {
          _username = 'User';
          _userRole = 'user';
          _profileImageUrl = null;
        });
      },
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _startAutoSlide(
      PageController controller, int length, Function(int) onPageChanged) {
    if (length == 0) return;

    Timer? timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      int nextPage = (controller.page?.toInt() ?? 0) + 1;
      if (nextPage >= length) nextPage = 0;
      controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      onPageChanged(nextPage);
    });

    if (controller == _firstSliderController) {
      _firstSliderTimer = timer;
    } else if (controller == _rewardsSliderController) {
      _rewardsSliderTimer = timer;
    }
  }

  @override
  void dispose() {
    _firstSliderTimer?.cancel();
    _rewardsSliderTimer?.cancel();
    _firstSliderController.dispose();
    _rewardsSliderController.dispose();
    _animationController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(
        title: "Home",
        isAgentScreen: _userRole == 'agent',
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {}); // Already set up to refresh the badge count
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntroSection(),
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          icon: Icons.lightbulb_outline,
                          iconColor: AppTheme.accentColor,
                          title: "Want Useful Recycling Tips?",
                          actionText: "Learn More",
                          onActionPressed: () {
                            Navigator.pushNamed(context, AppRoutes.recyclingTips); // Updated to use named route
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildImageSlider(
                          controller: _firstSliderController,
                          images: firstSliderImages,
                          height: screenWidth < 600 ? 200 : 220,
                          width: double.infinity,
                          currentIndex: _currentIndex,
                        ),
                        const SizedBox(height: 12),
                        _buildDotsIndicator(firstSliderImages, _currentIndex),
                        const SizedBox(height: 32),
                        _buildSectionHeader(
                          icon: Icons.star_border,
                          iconColor: AppTheme.accentColor,
                          title: "Participate and Earn",
                          actionText: "Learn More",
                          onActionPressed: () {
                            ExceptionHandling.showSnackBar(context, 'Learn More not implemented');
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildImageSlider(
                          controller: _rewardsSliderController,
                          images: rewardsSliderImages,
                          height: screenWidth < 600 ? 160 : 180,
                          width: double.infinity,
                          currentIndex: _currentRewardIndex,
                        ),
                        const SizedBox(height: 12),
                        _buildDotsIndicator(rewardsSliderImages, _currentRewardIndex),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.accentColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${_username ?? 'User'}!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recycle, earn rewards, and contribute to a greener planet with our app. Keep recycling!!!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.secondaryTextColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.recycling,
            color: AppTheme.primaryColor,
            size: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String actionText,
    required VoidCallback onActionPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTheme.sectionTitleStyle.copyWith(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        TextButton(
          onPressed: onActionPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            actionText,
            style: AppTheme.actionTextStyle.copyWith(
              color: AppTheme.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSlider({
    required PageController controller,
    required List<String> images,
    required double height,
    required double width,
    required int currentIndex,
  }) {
    if (images.isEmpty) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: AppTheme.cardColor,
        ),
        child: Center(
          child: Text(
            'No images available',
            style: AppTheme.bodyTextStyle.copyWith(
              color: AppTheme.secondaryTextColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: AppTheme.cardColor,
        ),
        child: PageView.builder(
          controller: controller,
          itemCount: images.length,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.cardColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: AppTheme.secondaryTextColor,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: AppTheme.bodyTextStyle.copyWith(
                              color: AppTheme.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDotsIndicator(List<String> images, int currentIndex) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        images.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: currentIndex == index ? 10 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index
                ? AppTheme.primaryColor
                : AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}