// lib/widgets/agent_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/extensions.dart';
import 'package:recycle_riti/utils/notification_manager.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/widgets/custom_button.dart';
import 'package:recycle_riti/widgets/detail_row.dart';
import 'package:url_launcher/url_launcher.dart';

class AgentDashboard extends StatefulWidget {
  final String? agentUsername;
  final String? currentAgentId;
  final Map<String, dynamic>? agentDetails;

  const AgentDashboard({
    super.key,
    this.agentUsername,
    this.currentAgentId,
    this.agentDetails,
  });

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  List<dynamic> _pickupRequests = [];
  List<dynamic> _filteredRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _lastRefreshed;
  String _selectedStatus = 'All';
  String? _selectedType;
  List<String> _recyclableTypes = [];
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  bool _selectAll = false;
  final Map<int, bool> _mapMaximizedStates = {};
  final Set<String> _deletedRequestIds = {};

  @override
  void initState() {
    super.initState();
    _fetchRecyclableTypes();
    _fetchPickupRequests();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecyclableTypes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.getRecyclableTypes(),
      defaultErrorMessage: 'Failed to fetch recyclable types',
      onSuccess: (response) {
        setState(() {
          _recyclableTypes = ['All'] + List<String>.from(response['types'].map((type) => type['name']));
          _selectedType = 'All';
        });
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
        });
      },
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterRequests();
    });
  }

  Future<void> _fetchPickupRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSelectionMode = false;
      _selectedIndices.clear();
      _selectAll = false;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.getPickupRequests(),
      defaultErrorMessage: 'Failed to fetch pickup requests',
      retryCallback: _fetchPickupRequests,
      onSuccess: (response) {
        if (mounted) {
          setState(() {
            _pickupRequests = response['pickupRequests'] ?? [];
            _pickupRequests.sort((a, b) {
              DateTime dateA = a['pickupDate'] != null
                  ? DateTime.parse(a['pickupDate'])
                  : DateTime.fromMillisecondsSinceEpoch(0);
              DateTime dateB = b['pickupDate'] != null
                  ? DateTime.parse(b['pickupDate'])
                  : DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA);
            });
            _filterRequests();
            _lastRefreshed = DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.now());
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
          });
        }
        print('AgentDashboard - Failed to fetch pickup requests: $error');
      },
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterRequests() {
    List<dynamic> tempRequests = _pickupRequests
        .where((request) => !_deletedRequestIds.contains(request['id']?.toString()))
        .toList();

    if (_selectedStatus != 'All') {
      tempRequests = tempRequests
          .where((request) => (request['status']?.toString() ?? '').toLowerCase() == _selectedStatus.toLowerCase())
          .toList();
    }

    if (_selectedType != null && _selectedType != 'All') {
      tempRequests = tempRequests.where((request) => request['recyclableType']?['name'] == _selectedType).toList();
    }

    if (_selectedDate != null) {
      tempRequests = tempRequests.where((request) {
        if (request['pickupDate'] == null) return false;
        DateTime pickupDate = DateTime.parse(request['pickupDate']);
        return pickupDate.year == _selectedDate!.year &&
            pickupDate.month == _selectedDate!.month &&
            pickupDate.day == _selectedDate!.day;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempRequests = tempRequests.where((request) {
        String userName = request['user']?['username']?.toString().toLowerCase() ?? '';
        return userName.contains(_searchQuery);
      }).toList();
    }

    setState(() {
      _filteredRequests = tempRequests;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor, onPrimary: Colors.white),
          textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 16), bodyMedium: TextStyle(fontSize: 14)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _filterRequests();
      });
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    if (requestId.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Invalid request ID');
      return;
    }

    await ExceptionHandling.handleVoidApiCall(
      context,
      () => AuthService.makeRequest('POST', 'pickup/assign/$requestId', body: {'agentId': widget.currentAgentId}),
      defaultErrorMessage: 'Failed to accept request',
      onSuccess: () {
        ExceptionHandling.showSnackBar(context, 'Request accepted successfully');
        _fetchPickupRequests();
      },
    );
  }

  Future<void> _cancelRequest(String requestId) async {
    if (requestId.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Invalid request ID');
      return;
    }

    // Find the request to check its status and assignment
    Map<String, dynamic>? request = _pickupRequests.firstWhere(
      (req) => req['id']?.toString() == requestId,
      orElse: () => {},
    );

    if (request!.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Request not found');
      return;
    }

    String? requestStatus = request['status']?.toString().toLowerCase();
    if (requestStatus != 'accepted') {
      ExceptionHandling.showSnackBar(context, 'Only accepted requests can be cancelled by the assigned agent');
      return;
    }

    bool isAssignedToAgent = request['agent'] != null && request['agent']['id']?.toString() == widget.currentAgentId;
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

    await ExceptionHandling.handleVoidApiCall(
      context,
      () => AuthService.makeRequest('PUT', 'pickup/cancel/$requestId', body: {'agentId': widget.currentAgentId}),
      defaultErrorMessage: 'Failed to cancel request',
      onSuccess: () {
        print('AgentDashboard - Cancellation triggered for request ID: $requestId');
        ExceptionHandling.showSnackBar(context, 'Request cancelled successfully');
        _fetchPickupRequests();
      },
      onError: (error) {
        if (error.contains('403')) {
          ExceptionHandling.showSnackBar(context, 'Not authorized to cancel this request. Please contact support if this issue persists.');
        }
      },
    );
  }

  Future<void> _deleteRequest(String requestId) async {
    if (requestId.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Invalid request ID');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Request',
          style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
        ),
        content: Text(
          'Are you sure you want to delete this request? This action cannot be undone.',
          style: AppTheme.bodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No", style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _deletedRequestIds.add(requestId);
      _pickupRequests.removeWhere((request) => request['id']?.toString() == requestId);
      _filterRequests();
    });

    // Delete related notifications
    await NotificationManager.deleteNotification(requestId);

    ExceptionHandling.showSnackBar(context, 'Request deleted successfully');
  }

  Future<void> _markAsCompleted(String requestId) async {
    if (requestId.isEmpty) {
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

    await ExceptionHandling.handleVoidApiCall(
      context,
      () => AuthService.makeRequest('PUT', 'pickup/complete/$requestId', body: {}),
      defaultErrorMessage: 'Failed to mark request as completed',
      onSuccess: () {
        ExceptionHandling.showSnackBar(context, 'Request marked as completed');
        _fetchPickupRequests();
      },
    );
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ExceptionHandling.showSnackBar(context, "User's phone number not available");
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
      ExceptionHandling.showSnackBar(context, "User's phone number not available");
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

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedIndices.clear();
        _selectAll = false;
      } else {
        _selectedIndices.clear();
        for (int i = 0; i < _filteredRequests.length; i++) {
          _selectedIndices.add(i);
        }
        _selectAll = true;
      }
    });
  }

  void _viewRequestDetails(String requestId) {
    if (requestId.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Invalid request ID');
      return;
    }

    try {
      Navigator.pushNamed(context, '/track-request-agent', arguments: {'requestId': requestId});
    } catch (e) {
      print('Navigation error to track-request-agent: $e');
      ExceptionHandling.showSnackBar(context, 'Navigation failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3))
                : _errorMessage != null
                    ? _buildErrorState()
                    : RefreshIndicator(
                        onRefresh: _fetchPickupRequests,
                        color: AppTheme.primaryColor,
                        backgroundColor: Colors.white,
                        child: _filteredRequests.isEmpty
                            ? _buildEmptyState()
                            : AnimationLimiter(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredRequests.length,
                                  itemBuilder: (context, index) {
                                    return AnimationConfiguration.staggeredList(
                                      position: index,
                                      duration: const Duration(milliseconds: 375),
                                      child: SlideAnimation(
                                        verticalOffset: 50.0,
                                        child: FadeInAnimation(
                                          child: _buildRequestTile(_filteredRequests[index], index),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Welcome, ${widget.agentUsername ?? 'Agent'}',
                style: AppTheme.sectionTitleStyle.copyWith(
                  fontSize: 24,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    style: AppTheme.bodyTextStyle.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by user name...',
                      hintStyle: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.primaryColor, size: 20),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: DropdownButton<String>(
                  value: _selectedType,
                  items: _recyclableTypes
                      .map((type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type, style: AppTheme.bodyTextStyle.copyWith(fontSize: 14, color: AppTheme.textColor)),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedType = value;
                    _filterRequests();
                  }),
                  underline: Container(),
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor, size: 20),
                  style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.textColor, fontSize: 14),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 24),
                onPressed: _fetchPickupRequests,
                tooltip: 'Refresh',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total: ${_filteredRequests.length}',
                  style: AppTheme.bodyTextStyle.copyWith(
                    fontSize: 14,
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  items: ['All', 'Pending', 'Accepted', 'Completed', 'Cancelled']
                      .map((status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status,
                              style: AppTheme.bodyTextStyle.copyWith(
                                fontSize: 14,
                                color: AppTheme.textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedStatus = value!;
                    _filterRequests();
                  }),
                  underline: Container(),
                  icon: const Icon(Icons.filter_list, color: AppTheme.primaryColor, size: 20),
                  style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.textColor, fontSize: 14),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
                  onPressed: _selectDate,
                  tooltip: 'Filter by Date',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
              if (_selectedDate != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.1),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.redAccent, size: 20),
                    onPressed: () => setState(() {
                      _selectedDate = null;
                      _filterRequests();
                    }),
                    tooltip: 'Clear Date Filter',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_lastRefreshed != null)
                Expanded(
                  child: Text(
                    'Last Refreshed: $_lastRefreshed',
                    style: AppTheme.bodyTextStyle.copyWith(
                      fontSize: 12,
                      color: AppTheme.secondaryTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Filtered Date: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
                style: AppTheme.bodyTextStyle.copyWith(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CustomButton(
            onPressed: _fetchPickupRequests,
            color: AppTheme.primaryColor,
            child: const Text(
              "Retry",
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 50, color: AppTheme.secondaryTextColor),
          const SizedBox(height: 16),
          Text(
            'No ${_selectedStatus == 'All' ? '' : _selectedStatus.toLowerCase()} pickup requests available',
            style: AppTheme.bodyTextStyle.copyWith(fontSize: 18, color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request, int index) {
    final String formattedDate = request['pickupDate'] != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['pickupDate']).toLocal())
        : 'N/A';
    final bool isAssignedToAgent = request['agent'] != null && request['agent']?['id']?.toString() == widget.currentAgentId;
    final bool isPending = (request['status']?.toString() ?? '').toLowerCase() == 'pending' && request['agent'] == null;
    final bool isAccepted = (request['status']?.toString() ?? '').toLowerCase() == 'accepted' && isAssignedToAgent;
    final bool isCompleted = (request['status']?.toString() ?? '').toLowerCase() == 'completed';
    final bool isCancelled = (request['status']?.toString() ?? '').toLowerCase() == 'cancelled';

    double? userLat;
    double? userLng;
    String? locationError;
    if (request['location'] != null) {
      try {
        final location = request['location'].toString();
        final parts = location.split(',');
        if (parts.length == 2) {
          userLat = double.tryParse(parts[0].split(':')[1]);
          userLng = double.tryParse(parts[1].split(':')[1]);
          if (userLat == null || userLng == null) {
            locationError = 'Invalid location coordinates';
          }
        } else {
          locationError = 'Invalid location format';
        }
      } catch (e) {
        locationError = 'Error parsing location: $e';
      }
    } else {
      locationError = 'Location not available';
    }

    Color statusBackgroundColor;
    Color statusDotColor;
    switch ((request['status']?.toString() ?? '').toLowerCase()) {
      case 'pending':
        statusBackgroundColor = Colors.orange.withOpacity(0.1);
        statusDotColor = Colors.orange;
        break;
      case 'accepted':
        statusBackgroundColor = Colors.blue.withOpacity(0.1);
        statusDotColor = Colors.blue;
        break;
      case 'completed':
        statusBackgroundColor = Colors.green.withOpacity(0.1);
        statusDotColor = Colors.green;
        break;
      case 'cancelled':
        statusBackgroundColor = Colors.redAccent.withOpacity(0.1);
        statusDotColor = Colors.redAccent;
        break;
      default:
        statusBackgroundColor = Colors.grey.withOpacity(0.1);
        statusDotColor = Colors.grey;
    }

    return GestureDetector(
      onLongPress: () {
        if (_selectedStatus != 'All') {
          setState(() {
            _isSelectionMode = true;
            _selectedIndices.add(index);
          });
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedIndices.contains(index)) {
              _selectedIndices.remove(index);
            } else {
              _selectedIndices.add(index);
            }
            if (_selectedIndices.isEmpty) {
              _isSelectionMode = false;
            }
          });
        } else {
          _viewRequestDetails(request['id']?.toString() ?? '');
        }
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                statusBackgroundColor,
              ],
            ),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_isSelectionMode)
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 200),
                        offset: const Offset(0, 0),
                        child: Checkbox(
                          value: _selectedIndices.contains(index),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIndices.add(index);
                              } else {
                                _selectedIndices.remove(index);
                                if (_selectedIndices.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              }
                            });
                          },
                          activeColor: AppTheme.primaryColor,
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusDotColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Request #${request['id']?.toString() ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DetailRow(
                            label: 'Status',
                            value: request['status']?.toString().capitalize() ?? 'Unknown',
                            valueColor: statusDotColor,
                          ),
                          const SizedBox(height: 4),
                          DetailRow(
                            label: 'User',
                            value: request['user']?['username']?.toString() ?? 'Unknown',
                          ),
                          const SizedBox(height: 4),
                          DetailRow(
                            label: 'Email',
                            value: request['user']?['email']?.toString() ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DetailRow(
                            label: 'Type',
                            value: request['recyclableType']?['name']?.toString() ?? 'N/A',
                          ),
                          const SizedBox(height: 4),
                          DetailRow(
                            label: 'Quantity',
                            value: request['quantity'] != null ? "${request['quantity']} kg" : '0 kg',
                          ),
                          const SizedBox(height: 4),
                          DetailRow(
                            label: 'Date',
                            value: formattedDate,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.grey, height: 1),
                const SizedBox(height: 8),
                if (request['location'] != null) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _mapMaximizedStates[index] = !(_mapMaximizedStates[index] ?? false);
                      });

                      if (_mapMaximizedStates[index] == true && userLat != null && userLng != null) {
                        final fullMapController = flutter_map.MapController();
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(0),
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.black.withOpacity(0.9),
                                  child: flutter_map.FlutterMap(
                                    mapController: fullMapController,
                                    options: flutter_map.MapOptions(
                                      initialCenter: latlng.LatLng(userLat!, userLng!),
                                      initialZoom: 15,
                                      minZoom: 5,
                                      maxZoom: 20,
                                      onMapReady: () {
                                        fullMapController.move(latlng.LatLng(userLat!, userLng!), 15);
                                      },
                                    ),
                                    children: [
                                      flutter_map.TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      ),
                                      flutter_map.MarkerLayer(
                                        markers: [
                                          flutter_map.Marker(
                                            point: latlng.LatLng(userLat, userLng),
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
                                  ),
                                ),
                                Positioned(
                                  top: 40,
                                  right: 10,
                                  child: CustomButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    isMini: true,
                                    color: Colors.redAccent,
                                    child: const Icon(Icons.close, color: Colors.white),
                                  ),
                                ),
                                Positioned(
                                  bottom: 20,
                                  right: 10,
                                  child: Column(
                                    children: [
                                      CustomButton(
                                        onPressed: () {
                                          fullMapController.move(
                                            fullMapController.camera.center,
                                            fullMapController.camera.zoom + 1,
                                          );
                                        },
                                        isMini: true,
                                        child: const Icon(Icons.zoom_in, color: Colors.white),
                                      ),
                                      const SizedBox(height: 8),
                                      CustomButton(
                                        onPressed: () {
                                          fullMapController.move(
                                            fullMapController.camera.center,
                                            fullMapController.camera.zoom - 1,
                                          );
                                        },
                                        isMini: true,
                                        child: const Icon(Icons.zoom_out, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).whenComplete(() {
                          fullMapController.dispose();
                          setState(() {
                            _mapMaximizedStates[index] = false;
                          });
                        });
                      }
                    },
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        height: (_mapMaximizedStates[index] ?? false) ? 200 : 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: locationError != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      locationError,
                                      style: AppTheme.bodyTextStyle.copyWith(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : flutter_map.FlutterMap(
                                options: flutter_map.MapOptions(
                                  initialCenter: latlng.LatLng(userLat!, userLng!),
                                  initialZoom: 15,
                                  onMapReady: () {},
                                ),
                                children: [
                                  flutter_map.TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  ),
                                  flutter_map.MarkerLayer(
                                    markers: [
                                      flutter_map.Marker(
                                        point: latlng.LatLng(userLat, userLng),
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
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(color: Colors.grey, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPending || isAccepted || isCancelled) ...[
                      CustomButton(
                        onPressed: () => _makePhoneCall(request['user']?['phone']?.toString()),
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        isMini: true,
                        child: const Icon(Icons.call, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 8),
                      CustomButton(
                        onPressed: () => _sendMessage(request['user']?['phone']?.toString()),
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        isMini: true,
                        child: const Icon(Icons.message, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isPending) ...[
                      CustomButton(
                        onPressed: () => _acceptRequest(request['id']?.toString() ?? ''),
                        color: Colors.orange,
                        isMini: true,
                        child: const Text(
                          "Accept",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (isAccepted) ...[
                      CustomButton(
                        onPressed: () => _cancelRequest(request['id']?.toString() ?? ''),
                        color: Colors.redAccent,
                        isMini: true,
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomButton(
                        onPressed: () => _markAsCompleted(request['id']?.toString() ?? ''),
                        color: AppTheme.primaryColor,
                        isMini: true,
                        child: const Text(
                          "Complete",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (isCompleted || isCancelled) ...[
                      CustomButton(
                        onPressed: () => _deleteRequest(request['id']?.toString() ?? ''),
                        color: Colors.redAccent,
                        isMini: true,
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomButton(
                        onPressed: () => _viewRequestDetails(request['id']?.toString() ?? ''),
                        color: AppTheme.primaryColor,
                        isMini: true,
                        child: const Text(
                          "View",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}