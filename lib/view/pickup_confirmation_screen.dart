import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lottie/lottie.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/extensions.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';
import 'package:recycle_riti/widgets/custom_button.dart';
import 'package:recycle_riti/widgets/detail_row.dart';

class PickupConfirmationScreen extends StatefulWidget {
  final String requestId;

  const PickupConfirmationScreen({super.key, required this.requestId});

  @override
  State<PickupConfirmationScreen> createState() => _PickupConfirmationScreenState();
}

class _PickupConfirmationScreenState extends State<PickupConfirmationScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? pickupData;
  bool isLoading = true;
  String? errorMsg;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _animationController.forward();
    _fetchData();
    NotificationScreen.initNotifications(
      context,
      onNotificationReceived: () {
        setState(() {}); // Refresh the UI when a notification is received
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.trackPickupRequest(widget.requestId),
      defaultErrorMessage: 'Failed to load pickup details',
      retryCallback: _fetchData,
      onSuccess: (res) {
        setState(() {
          pickupData = res['pickupRequest'];
        });
      },
      onError: (error) {
        setState(() {
          errorMsg = error;
        });
      },
    );

    setState(() {
      isLoading = false;
    });
  }

  void _navigateToTrackRequest() {
    if (mounted) {
      try {
        Navigator.pushNamed(
          context,
          AppRoutes.trackRequestUser,
          arguments: {'requestId': widget.requestId},
        );
      } catch (e) {
        print('Navigation error to track-request-user: $e');
        ExceptionHandling.showSnackBar(context, 'Navigation failed: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  void _navigateToMain() {
    if (mounted) {
      try {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.main,
          (Route<dynamic> route) => false,
          arguments: {'tabIndex': 1},
        );
      } catch (e) {
        print('Navigation error to main: $e');
        ExceptionHandling.showSnackBar(context, 'Navigation failed: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  // Helper method to truncate long strings
  String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Pickup Confirmation",
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {}); // Refresh the UI when a notification is received
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
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              )
            : errorMsg != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 50,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMsg!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          onPressed: _fetchData,
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: AppTheme.primaryColor,
                    backgroundColor: Colors.white,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                                const SizedBox(height: 10),
                                Text(
                                  "Pickup Confirmation",
                                  style: AppTheme.sectionTitleStyle.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 80,
                                      backgroundColor: Colors.white,
                                      child: SizedBox(
                                        height: 120,
                                        width: 120,
                                        child: Lottie.network(
                                          'https://lottie.host/2b3162df-fbcd-43af-97a6-e21bdab70544/BOAsbVuoXe.json',
                                          fit: BoxFit.contain,
                                          onLoaded: (composition) {
                                            print('Lottie animation loaded');
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            print('Error loading Lottie animation: $error');
                                            return Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.error,
                                                  color: Colors.redAccent,
                                                  size: 40,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Failed to load animation',
                                                  style: AppTheme.bodyTextStyle.copyWith(
                                                    color: Colors.redAccent,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: Text(
                                    'Successfully Requested',
                                    style: AppTheme.sectionTitleStyle.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: AppTheme.primaryColor.withOpacity(0.2),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Card(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          AppTheme.primaryColor.withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pickup Details',
                                          style: AppTheme.sectionTitleStyle.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  DetailRow(
                                                    label: 'Request ID',
                                                    value: _truncateString(
                                                      pickupData?['id']?.toString() ?? 'N/A',
                                                      15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DetailRow(
                                                    label: 'Recyclable Type',
                                                    value: _truncateString(
                                                      pickupData?['recyclableType']?['name']?.toString() ?? 'N/A',
                                                      15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DetailRow(
                                                    label: 'Quantity',
                                                    value: _truncateString(
                                                      pickupData?['quantity'] != null ? '${pickupData!['quantity']} kg' : 'N/A',
                                                      15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DetailRow(
                                                    label: 'Frequency',
                                                    value: _truncateString(
                                                      pickupData?['frequency']?.toString() ?? 'N/A',
                                                      15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  DetailRow(
                                                    label: 'Pickup Date',
                                                    value: _truncateString(
                                                      pickupData?['pickupDate'] != null
                                                          ? DateTime.parse(pickupData!['pickupDate']).toLocal().toString().split('.')[0]
                                                          : 'N/A',
                                                      20,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DetailRow(
                                                    label: 'Location',
                                                    value: _truncateString(
                                                      pickupData?['location']?.toString() ?? 'Not specified',
                                                      20,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DetailRow(
                                                    label: 'Status',
                                                    value: _truncateString(
                                                      pickupData?['status']?.toString().capitalize() ?? 'N/A',
                                                      15,
                                                    ),
                                                    valueColor: (pickupData?['status']?.toString() ?? '').toLowerCase() == 'pending'
                                                        ? Colors.orange
                                                        : (pickupData?['status']?.toString() ?? '').toLowerCase() == 'cancelled'
                                                            ? Colors.redAccent
                                                            : Colors.green,
                                                  ),
                                                  if (pickupData?['status'] == 'accepted' && pickupData?['assignments']?['agent'] != null) ...[
                                                    const SizedBox(height: 8),
                                                    DetailRow(
                                                      label: 'Agent',
                                                      value: _truncateString(
                                                        pickupData?['assignments']?['agent']?['username']?.toString() ?? 'N/A',
                                                        15,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (pickupData?['status'] == 'accepted' && pickupData?['assignments']?['agent'] != null) ...[
                                          const SizedBox(height: 8),
                                          DetailRow(
                                            label: 'Estimated Arrival',
                                            value: _truncateString(
                                              pickupData?['estimatedArrival'] != null
                                                  ? DateTime.parse(pickupData!['estimatedArrival']).toLocal().toString().split('.')[0]
                                                  : 'N/A',
                                              20,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomButton(
                                      onPressed: _navigateToMain,
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check, size: 18, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            'Done',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    CustomButton(
                                      onPressed: _navigateToTrackRequest,
                                      isOutlined: true,
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.track_changes, size: 18, color: AppTheme.primaryColor),
                                          SizedBox(width: 8),
                                          Text(
                                            'Track Request',
                                            style: TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}// 1202
// 24982
// 22604
