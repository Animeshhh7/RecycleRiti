// lib/view/track_request_screen_agent.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/extensions.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';
import 'package:recycle_riti/widgets/custom_button.dart';
import 'package:recycle_riti/widgets/detail_row.dart';
import 'package:recycle_riti/widgets/timeline_tile.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackRequestScreenAgent extends StatefulWidget {
  final String requestId;

  const TrackRequestScreenAgent({super.key, required this.requestId});

  @override
  State<TrackRequestScreenAgent> createState() => _TrackRequestScreenAgentState();
}

class _TrackRequestScreenAgentState extends State<TrackRequestScreenAgent> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? requestData;
  String? errorMsg;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final flutter_map.MapController _mapController = flutter_map.MapController();
  double? _userLat;
  double? _userLng;
  bool _isMapReady = false;
  bool _isMapMaximized = false;
  String? currentAgentId;

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
    _fetchCurrentAgentId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {}); // Refresh the UI when a notification is received
        },
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentAgentId() async {
    try {
      final response = await AuthService.getUserProfile();
      if (response['success']) {
        setState(() {
          currentAgentId = response['user']['id']?.toString();
        });
      }
    } catch (e) {
      print('TrackRequestScreenAgent: Failed to fetch current agent ID - $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.trackPickupRequest(widget.requestId),
      defaultErrorMessage: 'Failed to load request',
      retryCallback: _fetchData,
      onSuccess: (data) {
        setState(() {
          requestData = data['pickupRequest'];
          if (requestData?['location'] != null) {
            final location = requestData!['location'].toString();
            final parts = location.split(',');
            if (parts.length == 2) {
              _userLat = double.tryParse(parts[0].split(':')[1]);
              _userLng = double.tryParse(parts[1].split(':')[1]);
            }
          }
          print('TrackRequestScreenAgent: Fetched request data: $requestData');
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

  Future<void> _cancelRequest() async {
    if (widget.requestId.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Invalid request ID');
      return;
    }

    if (requestData?['status']?.toString().toLowerCase() != 'accepted') {
      ExceptionHandling.showSnackBar(context, 'Only accepted requests can be cancelled by the assigned agent');
      return;
    }

    bool isAssignedToAgent = requestData?['agent'] != null && requestData?['agent']['id']?.toString() == currentAgentId;
    if (!isAssignedToAgent) {
      ExceptionHandling.showSnackBar(context, 'You are not authorized to cancel this request');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Cancel Pickup Request",
          style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
        ),
        content: Text(
          "Are you sure you want to cancel this pickup request?",
          style: AppTheme.bodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No", style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    await ExceptionHandling.handleVoidApiCall(
      context,
      () => AuthService.makeRequest('PUT', 'pickup/cancel/${widget.requestId}', body: {'agentId': currentAgentId}),
      defaultErrorMessage: 'Failed to cancel request',
      onSuccess: () {
        ExceptionHandling.showSnackBar(context, 'Request cancelled successfully');
        _fetchData();
      },
      onError: (error) {
        if (error.contains('403')) {
          ExceptionHandling.showSnackBar(context, 'Not authorized to cancel this request. Please contact support if this issue persists.');
        }
      },
    );

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _markAsCompleted() async {
    if (widget.requestId.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Invalid request ID');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Mark as Completed",
          style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
        ),
        content: Text(
          "Are you sure you want to mark this pickup request as completed?",
          style: AppTheme.bodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No", style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    await ExceptionHandling.handleVoidApiCall(
      context,
      () => AuthService.makeRequest('PUT', 'pickup/complete/${widget.requestId}', body: {}),
      defaultErrorMessage: 'Failed to mark request as completed',
      onSuccess: () {
        ExceptionHandling.showSnackBar(context, 'Request marked as completed');
        _fetchData();
      },
    );

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ExceptionHandling.showSnackBar(context, "Phone number not available");
      return;
    }
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ExceptionHandling.showSnackBar(context, "Unable to make a phone call");
    }
  }

  Future<void> _sendMessage(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ExceptionHandling.showSnackBar(context, "Phone number not available");
      return;
    }
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': 'Hello, I am the agent handling your pickup request.'},
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      ExceptionHandling.showSnackBar(context, "Unable to send a message");
    }
  }

  @override
  Widget build(BuildContext context) {
    String? userProfileImageUrl = requestData?['user']?['profileImage'] != null
        ? '${AuthService.baseUrl.replaceAll('/api', '')}${requestData!['user']['profileImage']}?t=${DateTime.now().millisecondsSinceEpoch}'
        : null;
    bool isAssignedToAgent = requestData?['agent'] != null && requestData?['agent']['id']?.toString() == currentAgentId;

    return Scaffold(
      appBar: CustomAppBar(
        title: "Track Request",
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
                          style: AppTheme.bodyTextStyle.copyWith(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          onPressed: _fetchData,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Retry',
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
                        padding: const EdgeInsets.all(16),
                        child: AnimationLimiter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: AnimationConfiguration.toStaggeredList(
                              duration: const Duration(milliseconds: 600),
                              childAnimationBuilder: (widget) => SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: widget,
                                ),
                              ),
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  "Request Details",
                                  style: AppTheme.sectionTitleStyle.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Request ID: ${requestData?['id']?.toString() ?? 'N/A'}",
                                            style: AppTheme.sectionTitleStyle.copyWith(
                                              fontSize: 18,
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: (requestData?['status']?.toString() ?? '').toLowerCase() == 'pending'
                                                  ? Colors.orange.withOpacity(0.1)
                                                  : (requestData?['status']?.toString() ?? '').toLowerCase() == 'cancelled'
                                                      ? Colors.redAccent.withOpacity(0.1)
                                                      : Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20.0),
                                            ),
                                            child: Text(
                                              requestData?['status']?.toString().capitalize() ?? 'N/A',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: (requestData?['status']?.toString() ?? '').toLowerCase() == 'pending'
                                                    ? Colors.orange
                                                    : (requestData?['status']?.toString() ?? '').toLowerCase() == 'cancelled'
                                                        ? Colors.redAccent
                                                        : Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      DetailRow(
                                        label: "Recyclable Type",
                                        value: requestData?['recyclableType']?['name']?.toString() ?? 'N/A',
                                      ),
                                      DetailRow(
                                        label: "Quantity",
                                        value: requestData?['quantity'] != null ? "${requestData!['quantity']} kg" : 'N/A',
                                      ),
                                      DetailRow(
                                        label: "Pickup Date",
                                        value: requestData?['pickupDate'] != null
                                            ? DateTime.parse(requestData!['pickupDate']).toLocal().toString().split('.')[0]
                                            : 'N/A',
                                      ),
                                      DetailRow(
                                        label: "Frequency",
                                        value: requestData?['frequency']?.toString() ?? 'N/A',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  "User Details",
                                  style: AppTheme.sectionTitleStyle.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildCard(
                                  child: requestData?['user'] == null
                                      ? const Center(
                                          child: Text(
                                            "User information not available",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppTheme.primaryColor,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor: Colors.grey.shade200,
                                                    child: userProfileImageUrl != null
                                                        ? ClipOval(
                                                            child: CachedNetworkImage(
                                                              imageUrl: userProfileImageUrl,
                                                              fit: BoxFit.cover,
                                                              width: 48,
                                                              height: 48,
                                                              placeholder: (context, url) => const CircularProgressIndicator(
                                                                color: AppTheme.primaryColor,
                                                                strokeWidth: 2,
                                                              ),
                                                              errorWidget: (context, url, error) {
                                                                print('TrackRequestScreenAgent: Error loading user profile image - $error');
                                                                return Icon(
                                                                  Icons.person,
                                                                  color: AppTheme.primaryColor,
                                                                  size: 30,
                                                                );
                                                              },
                                                            ),
                                                          )
                                                        : Icon(
                                                            Icons.person,
                                                            color: AppTheme.primaryColor,
                                                            size: 30,
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        requestData?['user']?['username']?.toString() ?? 'Unknown User',
                                                        style: AppTheme.bodyTextStyle.copyWith(
                                                          fontWeight: FontWeight.w500,
                                                          color: AppTheme.textColor,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        requestData?['user']?['email']?.toString() ?? 'No email provided',
                                                        style: AppTheme.bodyTextStyle.copyWith(
                                                          fontSize: 14,
                                                          color: AppTheme.secondaryTextColor,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        requestData?['user']?['phone']?.toString() ?? 'No phone provided',
                                                        style: AppTheme.bodyTextStyle.copyWith(
                                                          fontSize: 14,
                                                          color: AppTheme.secondaryTextColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (requestData?['user']?['phone'] != null &&
                                                    requestData!['user']['phone'].toString().isNotEmpty) ...[
                                                  IconButton(
                                                    icon: const Icon(Icons.message, color: AppTheme.primaryColor, size: 28),
                                                    onPressed: () => _sendMessage(requestData?['user']?['phone']?.toString()),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.call, color: AppTheme.primaryColor, size: 28),
                                                    onPressed: () => _makePhoneCall(requestData?['user']?['phone']?.toString()),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 20),
                                if (requestData?['location'] != null) ...[
                                  Text(
                                    "Pickup Location",
                                    style: AppTheme.sectionTitleStyle.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isMapMaximized = !_isMapMaximized;
                                      });
                                    },
                                    child: Card(
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Container(
                                        height: _isMapMaximized ? 300 : 200,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(15),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white,
                                              AppTheme.primaryColor.withOpacity(0.05),
                                            ],
                                          ),
                                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: _userLat != null && _userLng != null
                                            ? flutter_map.FlutterMap(
                                                mapController: _mapController,
                                                options: flutter_map.MapOptions(
                                                  initialCenter: latlng.LatLng(_userLat!, _userLng!),
                                                  initialZoom: 15,
                                                  onMapReady: () {
                                                    setState(() {
                                                      _isMapReady = true;
                                                    });
                                                    if (_userLat != null && _userLng != null) {
                                                      _mapController.move(latlng.LatLng(_userLat!, _userLng!), 15);
                                                    }
                                                  },
                                                ),
                                                children: [
                                                  flutter_map.TileLayer(
                                                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                    subdomains: const ['a', 'b', 'c'],
                                                  ),
                                                  flutter_map.MarkerLayer(
                                                    markers: [
                                                      flutter_map.Marker(
                                                        point: latlng.LatLng(_userLat!, _userLng!),
                                                        width: 40,
                                                        height: 40,
                                                        child: const Icon(
                                                          Icons.location_pin,
                                                          color: Colors.red,
                                                          size: 40,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              )
                                            : const Center(child: CircularProgressIndicator()),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                if (requestData?['status'] == 'accepted' && isAssignedToAgent) ...[
                                  Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CustomButton(
                                          onPressed: _cancelRequest,
                                          color: Colors.redAccent,
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.cancel, size: 18, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text(
                                                'Cancel Request',
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
                                          onPressed: _markAsCompleted,
                                          color: AppTheme.primaryColor,
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle, size: 18, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text(
                                                'Mark as Completed',
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
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                Text(
                                  "Status Timeline",
                                  style: AppTheme.sectionTitleStyle.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TimelineTile(
                                  status: requestData?['status'] == 'cancelled' ? 'cancelled' : 'completed',
                                  title: "Request Confirmed",
                                  date: requestData?['createdAt'] != null
                                      ? DateTime.parse(requestData!['createdAt']).toLocal().toString().split('.')[0]
                                      : 'N/A',
                                  isFirst: true,
                                ),
                                TimelineTile(
                                  status: (requestData?['status'] == 'accepted' ||
                                          requestData?['status'] == 'completed')
                                      ? 'completed'
                                      : requestData?['status'] == 'cancelled'
                                          ? 'cancelled'
                                          : 'pending',
                                  title: "Agent on the Way",
                                  date: (requestData?['status'] == 'accepted' || requestData?['status'] == 'completed')
                                      ? (requestData?['updatedAt'] != null
                                          ? DateTime.parse(requestData!['updatedAt']).toLocal().toString().split('.')[0]
                                          : 'N/A')
                                      : 'Pending',
                                ),
                                TimelineTile(
                                  status: requestData?['status'] == 'completed'
                                      ? 'completed'
                                      : requestData?['status'] == 'cancelled'
                                          ? 'cancelled'
                                          : 'pending',
                                  title: "Successfully Completed Pickup",
                                  date: requestData?['status'] == 'completed'
                                      ? (requestData?['updatedAt'] != null
                                          ? DateTime.parse(requestData!['updatedAt']).toLocal().toString().split('.')[0]
                                          : 'N/A')
                                      : 'Pending',
                                  isLast: requestData?['status'] != 'cancelled',
                                ),
                                if (requestData?['status'] == 'cancelled') ...[
                                  TimelineTile(
                                    status: 'cancelled',
                                    title: "Request Cancelled",
                                    date: requestData?['updatedAt'] != null
                                        ? DateTime.parse(requestData!['updatedAt']).toLocal().toString().split('.')[0]
                                        : 'N/A',
                                    isLast: true,
                                  ),
                                ],
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

  Widget _buildCard({required Widget child}) {
    return Card(
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
        child: child,
      ),
    );
  }
}