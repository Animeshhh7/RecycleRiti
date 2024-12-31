import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';
import 'package:recycle_riti/widgets/custom_button.dart';
import 'package:recycle_riti/widgets/detail_row.dart';

class PickupHistoryScreen extends StatefulWidget {
  const PickupHistoryScreen({super.key});

  @override
  State<PickupHistoryScreen> createState() => _PickupHistoryScreenState();
}

class _PickupHistoryScreenState extends State<PickupHistoryScreen> {
  List<dynamic>? _pastRequests;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchPastRequests();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          if (mounted) {
            setState(() {});
          }
          print('PickupHistoryScreen: Notification received, refreshing UI');
        },
      );
    });
  }

  @override
  void dispose() {
    NotificationScreen.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    try {
      final response = await AuthService.getUserProfile();
      if (response['success']) {
        if (mounted) {
          setState(() {
            _userRole = response['user']['role']?.toString().toLowerCase();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userRole = 'user';
          });
        }
      }
    } catch (e) {
      print('Failed to fetch user role: $e');
      if (mounted) {
        setState(() {
          _userRole = 'user';
        });
      }
    }
  }

  Future<void> _fetchPastRequests() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> response = _userRole == 'agent'
          ? await AuthService.getAgentPickupRequests()
          : await AuthService.getPickupRequests();
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to fetch pickup history');
      }

      List<dynamic> requests = response['pickupRequests'] ?? [];
      print('PickupHistoryScreen: Fetched ${requests.length} requests for role: $_userRole');
      print('PickupHistoryScreen: Raw requests: $requests');

      // Filter for completed requests
      List<dynamic> filteredRequests = requests.where((request) {
        final status = request['status']?.toString().toLowerCase();
        return status == 'completed';
      }).toList();
      print('PickupHistoryScreen: Filtered ${filteredRequests.length} completed requests');

      if (mounted) {
        setState(() {
          _pastRequests = filteredRequests;
          _pastRequests?.sort((a, b) {
            DateTime dateA = a['pickupDate'] != null
                ? DateTime.parse(a['pickupDate'])
                : DateTime.fromMillisecondsSinceEpoch(0);
            DateTime dateB = b['pickupDate'] != null
                ? DateTime.parse(b['pickupDate'])
                : DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
        });
      }
    } catch (e) {
      print('PickupHistoryScreen: Error fetching pickup history: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Pickup History',
        isAgentScreen: _userRole == 'agent',
        showNotifications: true,
        onNotificationStateChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPastRequests,
        color: AppTheme.primaryColor,
        child: Container(
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
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 3,
                  ),
                )
              : _errorMessage != null
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
                            _errorMessage!,
                            style: AppTheme.bodyTextStyle.copyWith(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          CustomButton(
                            onPressed: _fetchPastRequests,
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _pastRequests == null || _pastRequests!.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.history_toggle_off,
                                size: 50,
                                color: AppTheme.secondaryTextColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No completed pickup requests found',
                                style: AppTheme.bodyTextStyle.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        )
                      : AnimationLimiter(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pastRequests!.length,
                            itemBuilder: (context, index) {
                              final request = _pastRequests![index];
                              print('PickupHistoryScreen: Displaying request $index: $request');
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: Card(
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Container(
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
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Request ID: ${request['id']?.toString() ?? 'N/A'}',
                                                  style: AppTheme.sectionTitleStyle.copyWith(
                                                    fontSize: 16,
                                                    color: AppTheme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    'Completed',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            if (_userRole == 'agent') ...[
                                              DetailRow(
                                                label: 'User',
                                                value: request['user']?['username']?.toString() ?? 'Unknown',
                                              ),
                                              const SizedBox(height: 8),
                                              DetailRow(
                                                label: 'Email',
                                                value: request['user']?['email']?.toString() ?? 'N/A',
                                              ),
                                              const SizedBox(height: 8),
                                              DetailRow(
                                                label: 'Phone',
                                                value: request['user']?['phone']?.toString() ?? 'N/A',
                                              ),
                                            ],
                                            if (_userRole == 'user') ...[
                                              DetailRow(
                                                label: 'Agent',
                                                value: (request['assignments']?['agent']?['username']?.toString() ?? 'Not Assigned'),
                                              ),
                                              const SizedBox(height: 8),
                                              DetailRow(
                                                label: 'Agent Email',
                                                value: request['assignments']?['agent']?['email']?.toString() ?? 'N/A',
                                              ),
                                              const SizedBox(height: 8),
                                              DetailRow(
                                                label: 'Agent Phone',
                                                value: request['assignments']?['agent']?['phone']?.toString() ?? 'N/A',
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            DetailRow(
                                              label: 'Recyclable Type',
                                              value: request['recyclableType']?['name']?.toString() ?? 'N/A',
                                            ),
                                            const SizedBox(height: 8),
                                            DetailRow(
                                              label: 'Quantity',
                                              value: request['quantity'] != null ? "${request['quantity']} kg" : '0 kg',
                                            ),
                                            const SizedBox(height: 8),
                                            DetailRow(
                                              label: 'Pickup Date',
                                              value: request['pickupDate'] != null
                                                  ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['pickupDate']))
                                                  : 'N/A',
                                            ),
                                            const SizedBox(height: 12),
                                            if (request['location'] != null) ...[
                                              Card(
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Container(
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        Colors.white,
                                                        AppTheme.primaryColor.withOpacity(0.05),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        const Icon(
                                                          Icons.location_on,
                                                          size: 30,
                                                          color: AppTheme.primaryColor,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          "Location: ${request['location']}",
                                                          style: AppTheme.bodyTextStyle.copyWith(
                                                            color: AppTheme.textColor,
                                                            fontSize: 14,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
        ),
      );
  }
}// 27113
// 31285
// 8328
// 30757
