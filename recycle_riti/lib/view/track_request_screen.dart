// lib/view/track_request_screen_user.dart
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:lottie/lottie.dart';
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

class TrackRequestScreenUser extends StatefulWidget {
  final String requestId;

  const TrackRequestScreenUser({super.key, this.requestId = 'test-request-id-4'});

  @override
  State<TrackRequestScreenUser> createState() => _TrackRequestScreenUserState();
}

class _TrackRequestScreenUserState extends State<TrackRequestScreenUser> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? requestData;
  String? errorMsg;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final flutter_map.MapController _mapController = flutter_map.MapController();
  double? _agentLat;
  double? _agentLng;
  Timer? _locationTimer;
  bool _isMapReady = false;
  bool _isMapMaximized = false;

  static const String pendingAnimationUrl = 'https://lottie.host/04f82902-9e23-4361-9b7c-34edd4ba5381/ltEMsmT2BM.json';
  static const String acceptedAnimationUrl = 'https://lottie.host/53a2e3ab-2308-4066-8181-234a01726adb/AEBLIzmPfH.json';
  static const String completedAnimationUrl = 'https://lottie.host/d0de78d6-c7e9-467a-885f-fec1fdd99f54/8mNWvtfM8x.json';
  static const String cancelledAnimationUrl = 'https://lottie.host/d77148e5-ac21-48df-af85-3258607d1a5b/F6DzEyWjko.json';

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
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchAgentLocation());
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
    _locationTimer?.cancel();
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
      defaultErrorMessage: 'Failed to load request',
      retryCallback: _fetchData,
      onSuccess: (data) {
        setState(() {
          requestData = data['pickupRequest'];
          print('Request Data: $requestData');
          _fetchAgentLocation();
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

  Future<void> _fetchAgentLocation() async {
    try {
      final data = await AuthService.trackPickupRequest(widget.requestId);
      if (!data['success']) {
        throw Exception(data['message'] ?? 'Failed to fetch agent location');
      }
      setState(() {
        requestData = data['pickupRequest'];
        _agentLat = requestData?['agent']?['latitude'] ?? 37.7749;
        _agentLng = requestData?['agent']?['longitude'] ?? -122.4194;
      });
    } catch (e) {
      ExceptionHandling.showSnackBar(context, 'Failed to fetch agent location: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Cancel Pickup Request",
          style: AppTheme.sectionTitleStyle.copyWith(
            color: AppTheme.textColor,
          ),
        ),
        content: Text(
          "Are you sure you want to cancel this pickup request?",
          style: AppTheme.bodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "No",
              style: AppTheme.bodyTextStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Yes",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    await ExceptionHandling.handleApiCall(
      context,
      () => AuthService.makeRequest('PUT', 'pickup/cancel/${widget.requestId}', body: {}),
      defaultErrorMessage: 'Failed to cancel request',
      retryCallback: _cancelRequest,
      onSuccess: (response) {
        final data = jsonDecode(response.body);
        ExceptionHandling.showSnackBar(context, data['message'] ?? 'Request cancelled');
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
      queryParameters: {'body': 'Hello, I am the user tracking my pickup request.'},
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      ExceptionHandling.showSnackBar(context, "Unable to send a message");
    }
  }

  @override
  Widget build(BuildContext context) {
    String? agentProfileImageUrl = requestData?['agent']?['profileImage'] != null
        ? '${AuthService.baseUrl.replaceAll('/api', '')}${requestData!['agent']['profileImage']}?t=${DateTime.now().millisecondsSinceEpoch}'
        : null;

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
                                Center(
                                  child: SizedBox(
                                    width: 250,
                                    height: 250,
                                    child: Lottie.network(
                                      _getAnimationUrl(),
                                      fit: BoxFit.contain,
                                      repeat: true,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.error,
                                          color: Colors.redAccent,
                                          size: 50,
                                        );
                                      },
                                    ),
                                  ),
                                ),
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
                                if (requestData?['status'] == 'accepted' && requestData?['agent'] != null) ...[
                                  Text(
                                    "Agent Details",
                                    style: AppTheme.sectionTitleStyle.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.local_shipping,
                                                color: AppTheme.primaryColor, size: 28),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                requestData?['estimatedArrival'] != null
                                                    ? "Estimated Arrival: ${DateTime.parse(requestData!['estimatedArrival']).toLocal().toString().split('.')[0]}"
                                                    : "Estimated Arrival: N/A",
                                                style: AppTheme.bodyTextStyle.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 15),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isMapMaximized = !_isMapMaximized;
                                            });
                                          },
                                          child: Container(
                                            height: _isMapMaximized ? 300 : 200,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Stack(
                                                children: [
                                                  _agentLat != null && _agentLng != null
                                                      ? flutter_map.FlutterMap(
                                                          mapController: _mapController,
                                                          options: flutter_map.MapOptions(
                                                            initialCenter: latlng.LatLng(_agentLat!, _agentLng!),
                                                            initialZoom: 15,
                                                            onMapReady: () {
                                                              setState(() {
                                                                _isMapReady = true;
                                                              });
                                                              if (_agentLat != null && _agentLng != null) {
                                                                _mapController.move(latlng.LatLng(_agentLat!, _agentLng!), 15);
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
                                                                  point: latlng.LatLng(_agentLat!, _agentLng!),
                                                                  width: 40,
                                                                  height: 40,
                                                                  child: const Icon(
                                                                    Icons.directions_car,
                                                                    color: Colors.green,
                                                                    size: 40,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        )
                                                      : const Center(child: CircularProgressIndicator()),
                                                  if (_isMapMaximized)
                                                    Positioned(
                                                      top: 10,
                                                      right: 10,
                                                      child: CustomButton(
                                                        onPressed: _fetchAgentLocation,
                                                        isMini: true,
                                                        child: const Icon(Icons.refresh, color: Colors.white),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 15),
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
                                                child: agentProfileImageUrl != null
                                                    ? ClipOval(
                                                        child: CachedNetworkImage(
                                                          imageUrl: agentProfileImageUrl,
                                                          fit: BoxFit.cover,
                                                          width: 48,
                                                          height: 48,
                                                          placeholder: (context, url) => const CircularProgressIndicator(
                                                            color: AppTheme.primaryColor,
                                                            strokeWidth: 2,
                                                          ),
                                                          errorWidget: (context, url, error) {
                                                            print('TrackRequestScreenUser: Error loading agent profile image - $error');
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
                                                    requestData?['agent']?['username']?.toString() ?? 'N/A',
                                                    style: AppTheme.bodyTextStyle.copyWith(
                                                      fontWeight: FontWeight.w500,
                                                      color: AppTheme.textColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    requestData?['agent']?['phone']?.toString() ?? 'N/A',
                                                    style: AppTheme.bodyTextStyle.copyWith(
                                                      fontSize: 14,
                                                      color: AppTheme.secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.message,
                                                  color: AppTheme.primaryColor, size: 28),
                                              onPressed: () => _sendMessage(requestData?['agent']?['phone']?.toString()),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.call,
                                                  color: AppTheme.primaryColor, size: 28),
                                              onPressed: () => _makePhoneCall(requestData?['agent']?['phone']?.toString()),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                  Card(
                                    elevation: 6,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Container(
                                      height: 200,
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
                                      ),
                                      child: _buildPickupLocationMap(),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                if (requestData?['status'] == 'pending' || requestData?['status'] == 'accepted') ...[
                                  Center(
                                    child: CustomButton(
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

  String _getAnimationUrl() {
    final status = requestData?['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'pending':
        return pendingAnimationUrl;
      case 'accepted':
        return acceptedAnimationUrl;
      case 'completed':
        return completedAnimationUrl;
      case 'cancelled':
        return cancelledAnimationUrl;
      default:
        return pendingAnimationUrl;
    }
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

  Widget _buildPickupLocationMap() {
    double? pickupLat;
    double? pickupLng;

    if (requestData?['latitude'] != null && requestData?['longitude'] != null) {
      pickupLat = requestData!['latitude'];
      pickupLng = requestData!['longitude'];
    } else if (requestData?['location'] != null) {
      final location = requestData!['location'].toString();
      if (location.contains('lat:') && location.contains('lng:')) {
        try {
          final latPart = location.split('lat:')[1].split(',')[0].trim();
          final lngPart = location.split('lng:')[1].trim();
          pickupLat = double.parse(latPart);
          pickupLng = double.parse(lngPart);
        } catch (e) {
          print('Error parsing location coordinates: $e');
          return Center(
            child: Text(
              'Error parsing location coordinates',
              style: AppTheme.bodyTextStyle.copyWith(
                color: Colors.redAccent,
                fontSize: 14,
              ),
            ),
          );
        }
      }
    }

    if (pickupLat == null || pickupLng == null) {
      return Center(
        child: Text(
          'Location coordinates not available',
          style: AppTheme.bodyTextStyle.copyWith(
            color: AppTheme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
      );
    }

    return flutter_map.FlutterMap(
      options: flutter_map.MapOptions(
        initialCenter: latlng.LatLng(pickupLat, pickupLng),
        initialZoom: 15,
        onMapReady: () {},
      ),
      children: [
        flutter_map.TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.app',
          errorTileCallback: (tile, error, stackTrace) {
            print('Tile loading error: $error');
          },
        ),
        flutter_map.MarkerLayer(
          markers: [
            flutter_map.Marker(
              point: latlng.LatLng(pickupLat, pickupLng),
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
    );
  }
}