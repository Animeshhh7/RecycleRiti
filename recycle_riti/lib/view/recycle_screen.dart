// lib/view/recycle_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/data/recyclable_items.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';

class RecycleScreen extends StatefulWidget {
  const RecycleScreen({super.key});

  @override
  State<RecycleScreen> createState() => _RecycleScreenState();
}

class _RecycleScreenState extends State<RecycleScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _recyclableTabController;
  late TabController _nonRecyclableTabController;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // Initialize TabControllers for recyclable and non-recyclable categories
    _recyclableTabController = TabController(
      length: recyclableCategories.length,
      vsync: this,
    );
    _nonRecyclableTabController = TabController(
      length: nonRecyclableCategories.length,
      vsync: this,
    );
    _animationController.forward();
    // Initialize notifications with a callback to refresh the UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {}); // Refresh the UI when a notification is received
        },
      );
    });
    // Fetch user role to determine if user is an agent
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final response = await AuthService.getUserProfile();
      if (response['success']) {
        setState(() {
          _userRole = response['user']['role']?.toString().toLowerCase();
        });
      } else {
        setState(() {
          _userRole = 'user'; // Default to user if role fetch fails
        });
      }
    } catch (e) {
      print('Failed to fetch user role: $e');
      setState(() {
        _userRole = 'user'; // Default to user on error
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recyclableTabController.dispose();
    _nonRecyclableTabController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(
        title: "Recycle",
        isAgentScreen: _userRole == 'agent',
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {}); // Already set up to refresh the badge count
        },
      ),
      body: Container(
        // Background gradient consistent with app theme
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 20,
            ),
            child: AnimationLimiter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 600),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    // Header Section with Introduction
                    _buildHeaderSection(),
                    const SizedBox(height: 24),
                    // Recyclable Items Section (What We Take)
                    _buildRecyclableSection(),
                    const SizedBox(height: 32),
                    // Non-Recyclable Items Section (What We Don’t Take)
                    _buildNonRecyclableSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the header section with an introduction
  Widget _buildHeaderSection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.accentColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Learn About Recycling",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Discover what items we accept for recycling and what we cannot take. Let’s make the planet greener together!",
                    style: AppTheme.bodyTextStyle.copyWith(
                      fontSize: 16,
                      color: AppTheme.textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.recycling,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the recyclable items section (What We Take)
  Widget _buildRecyclableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "What We Take (Recyclable)",
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Items we accept for recycling, along with estimated prices per kg.",
          style: AppTheme.bodyTextStyle.copyWith(
            fontSize: 14,
            color: AppTheme.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 15),
        TabBar(
          controller: _recyclableTabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          tabs: recyclableCategories
              .map((category) => Tab(text: category.category))
              .toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: MediaQuery.of(context).size.width < 600 ? 600 : 650,
          child: TabBarView(
            controller: _recyclableTabController,
            children: recyclableCategories
                .map((category) => _buildItemsGrid(category.items))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Builds the non-recyclable items section (What We Don’t Take)
  Widget _buildNonRecyclableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.close,
              color: Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "What We Don’t Take (Non-Recyclable)",
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Items we cannot accept due to contamination or hazardous nature.",
          style: AppTheme.bodyTextStyle.copyWith(
            fontSize: 14,
            color: AppTheme.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 15),
        TabBar(
          controller: _nonRecyclableTabController,
          isScrollable: true,
          labelColor: Colors.redAccent,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          indicatorColor: Colors.redAccent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          tabs: nonRecyclableCategories
              .map((category) => Tab(text: category.category))
              .toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: MediaQuery.of(context).size.width < 600 ? 600 : 650,
          child: TabBarView(
            controller: _nonRecyclableTabController,
            children: nonRecyclableCategories
                .map((category) => _buildItemsGrid(category.items))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Builds a grid of items for the selected category
  Widget _buildItemsGrid(List<RecyclableItem> items) {
    return AnimationLimiter(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.55,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 2,
            duration: const Duration(milliseconds: 600),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildItemCard(item),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds a card for each recyclable or non-recyclable item
  Widget _buildItemCard(RecyclableItem item) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
          border: Border.all(
            color: item.isRecyclable ? AppTheme.primaryColor.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              item.isRecyclable ? AppTheme.primaryColor.withOpacity(0.05) : Colors.redAccent.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: Image.network(
                item.imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Title
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: item.isRecyclable ? AppTheme.primaryColor : Colors.redAccent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // Price or Reason
                  Text(
                    item.isRecyclable
                        ? 'Est. Rs ${item.pricePerKg.toStringAsFixed(0)}/kg'
                        : 'Not Accepted',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: item.isRecyclable ? AppTheme.textColor : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Description
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryTextColor,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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