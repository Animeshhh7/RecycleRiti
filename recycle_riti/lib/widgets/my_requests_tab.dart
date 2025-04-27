// lib/widgets/my_requests_tab.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/extensions.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/widgets/custom_button.dart';
import 'package:recycle_riti/widgets/detail_row.dart';

class MyRequestsTab extends StatefulWidget {
  const MyRequestsTab({super.key});

  @override
  State<MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<MyRequestsTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _requests = [];
  List<dynamic> _filteredRequests = [];
  String _selectedStatus = 'All';
  DateTime? _selectedDate;
  String _lastRefreshed = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  List<String> _recyclableTypes = [];
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchRecyclableTypes();
    _fetchRequests();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterRequests();
    });
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

  Future<void> _fetchRequests() async {
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
      () async {
        final token = await AuthService.getAccessToken();
        if (token == null || token.isEmpty) {
          throw Exception('No access token found. Please log in.');
        }
        return await AuthService.getPickupRequests();
      },
      defaultErrorMessage: 'Failed to fetch requests',
      onSuccess: (response) {
        setState(() {
          _requests = response['pickupRequests'] ?? [];
          _filterRequests();
          _lastRefreshed = DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.now());
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

  void _filterRequests() {
    var filtered = List.from(_requests);

    if (_selectedStatus != 'All') {
      filtered = filtered.where((request) => request['status']?.toLowerCase() == _selectedStatus.toLowerCase()).toList();
    }

    if (_selectedDate != null) {
      filtered = filtered.where((request) {
        if (request['pickupDate'] == null) return false;
        final pickupDate = DateTime.parse(request['pickupDate']).toLocal();
        return pickupDate.year == _selectedDate!.year &&
            pickupDate.month == _selectedDate!.month &&
            pickupDate.day == _selectedDate!.day;
      }).toList();
    }

    if (_selectedType != null && _selectedType != 'All') {
      filtered = filtered.where((request) => request['recyclableType']?['name'] == _selectedType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((request) {
        final agentName = request['agent']?['username']?.toString().toLowerCase();
        return agentName != null && agentName.contains(_searchQuery);
      }).toList();
    }

    filtered.sort((a, b) {
      final dateA = a['pickupDate'] != null ? DateTime.parse(a['pickupDate']) : DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b['pickupDate'] != null ? DateTime.parse(b['pickupDate']) : DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _filteredRequests = filtered;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor, onPrimary: Colors.white),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontSize: 16),
            bodyMedium: TextStyle(fontSize: 14),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _filterRequests();
      });
    }
  }

  Future<void> _clearCompletedRequests() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear Completed Pickups',
          style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
        ),
        content: Text(
          'Are you sure you want to clear all completed pickup requests? This action cannot be undone.',
          style: AppTheme.bodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
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
      _isLoading = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleVoidApiCall(
      context,
      () async {
        final completedRequests = _requests.where((request) => request['status']?.toLowerCase() == 'completed').toList();
        for (var request in completedRequests) {
          final requestId = request['id']?.toString();
          if (requestId != null) {
            final response = await AuthService.makeRequest('DELETE', 'pickup/requests/$requestId', body: {});
            Map<String, dynamic> data;
            try {
              data = jsonDecode(response.body);
            } catch (e) {
              throw Exception('Failed to parse server response: ${response.body}');
            }
            if (response.statusCode != 200) {
              if (response.statusCode == 404) {
                throw Exception('Request not found: $requestId');
              }
              throw Exception(data['message'] ?? 'Failed to delete request $requestId');
            }
            if (!(data['success'] ?? false)) {
              throw Exception(data['message'] ?? 'Failed to delete request $requestId');
            }
          }
        }
      },
      defaultErrorMessage: 'Failed to clear completed requests',
      onSuccess: () {
        ExceptionHandling.showSnackBar(context, 'Completed requests cleared successfully');
        _fetchRequests();
      },
    );

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteSelectedRequests() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Selected Requests',
          style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
        ),
        content: Text(
          'Are you sure you want to delete the selected requests? This action cannot be undone.',
          style: AppTheme.bodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
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
      _isLoading = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleVoidApiCall(
      context,
      () async {
        final selectedRequests = _filteredRequests.asMap().entries.where((entry) => _selectedIndices.contains(entry.key)).map((entry) => entry.value).toList();
        for (var request in selectedRequests) {
          final requestId = request['id']?.toString();
          if (requestId == null) {
            throw Exception('Invalid request ID');
          }
          print('Deleting request: $requestId, status: ${request['status']}');
          if (request['status']?.toLowerCase() == 'completed' || request['status']?.toLowerCase() == 'cancelled') {
            final response = await AuthService.makeRequest('DELETE', 'pickup/requests/$requestId', body: {});
            Map<String, dynamic> data;
            try {
              data = jsonDecode(response.body);
            } catch (e) {
              throw Exception('Failed to parse server response: ${response.body}');
            }
            print('Delete response: ${response.statusCode}, body: ${response.body}');
            if (response.statusCode != 200) {
              if (response.statusCode == 404) {
                throw Exception('Request not found: $requestId');
              }
              throw Exception(data['message'] ?? 'Failed to delete request $requestId');
            }
            if (!(data['success'] ?? false)) {
              throw Exception(data['message'] ?? 'Failed to delete request $requestId');
            }
          } else {
            throw Exception('Only completed or cancelled requests can be deleted');
          }
        }
      },
      defaultErrorMessage: 'Failed to delete selected requests',
      onSuccess: () {
        ExceptionHandling.showSnackBar(context, 'Selected requests deleted successfully');
        _fetchRequests();
      },
    );

    setState(() {
      _isLoading = false;
      _isSelectionMode = false;
      _selectedIndices.clear();
      _selectAll = false;
    });
  }

  Future<void> _cancelSelectedRequests() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Selected Requests',
          style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
        ),
        content: Text(
          'Are you sure you want to cancel the selected requests?',
          style: AppTheme.bodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
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
      _isLoading = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleVoidApiCall(
      context,
      () async {
        final selectedRequests = _filteredRequests.asMap().entries.where((entry) => _selectedIndices.contains(entry.key)).map((entry) => entry.value).toList();
        for (var request in selectedRequests) {
          final requestId = request['id']?.toString();
          if (requestId == null) {
            throw Exception('Invalid request ID');
          }
          print('Cancelling request: $requestId, status: ${request['status']}');
          if (request['status']?.toLowerCase() == 'accepted' || request['status']?.toLowerCase() == 'pending') {
            final response = await AuthService.makeRequest('PUT', 'pickup/cancel/$requestId', body: {});
            Map<String, dynamic> data;
            try {
              data = jsonDecode(response.body);
            } catch (e) {
              throw Exception('Failed to parse server response: ${response.body}');
            }
            print('Cancel response: ${response.statusCode}, body: ${response.body}');
            if (response.statusCode != 200) {
              if (response.statusCode == 404) {
                throw Exception('Request not found: $requestId');
              }
              throw Exception(data['message'] ?? 'Failed to cancel request $requestId');
            }
            if (!(data['success'] ?? false)) {
              throw Exception(data['message'] ?? 'Failed to cancel request $requestId');
            }
          } else {
            throw Exception('Only accepted or pending requests can be cancelled');
          }
        }
      },
      defaultErrorMessage: 'Failed to cancel selected requests',
      onSuccess: () {
        ExceptionHandling.showSnackBar(context, 'Selected requests cancelled successfully');
        _fetchRequests();
      },
    );

    setState(() {
      _isLoading = false;
      _isSelectionMode = false;
      _selectedIndices.clear();
      _selectAll = false;
    });
  }

  void _toggleSelectAll() {
    if (!mounted) return;
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

  void _navigateToTrackRequest(String requestId) {
    if (requestId.isEmpty) {
      ExceptionHandling.showSnackBar(context, 'Invalid request ID');
      return;
    }
    try {
      Navigator.pushNamed(context, AppRoutes.trackRequestUser, arguments: {'requestId': requestId});
    } catch (e) {
      print('Navigation error to track-request-user: $e');
      ExceptionHandling.showSnackBar(context, 'Navigation failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Widget _buildRequestTile(Map<String, dynamic> request, int index) {
    final String formattedDate = request['pickupDate'] != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['pickupDate']).toLocal())
        : 'N/A';
    final bool isPending = (request['status']?.toString() ?? '').toLowerCase() == 'pending';
    final bool isAccepted = (request['status']?.toString() ?? '').toLowerCase() == 'accepted';
    final bool isCompleted = (request['status']?.toString() ?? '').toLowerCase() == 'completed';
    final bool isCancelled = (request['status']?.toString() ?? '').toLowerCase() == 'cancelled';

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
        setState(() {
          _isSelectionMode = true;
          _selectedIndices.add(index);
        });
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
          _navigateToTrackRequest(request['id']?.toString() ?? '');
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: statusDotColor.withOpacity(0.2), width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                statusBackgroundColor,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusDotColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Request #${request['id'] ?? 'N/A'}',
                              style: AppTheme.sectionTitleStyle.copyWith(
                                fontSize: 14,
                                color: AppTheme.textColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                                  fontSize: 12,
                                ),
                                const SizedBox(height: 4),
                                DetailRow(
                                  label: 'Type',
                                  value: request['recyclableType']?['name']?.toString() ?? 'N/A',
                                  fontSize: 12,
                                ),
                                const SizedBox(height: 4),
                                DetailRow(
                                  label: 'Quantity',
                                  value: '${request['quantity']?.toString() ?? 'N/A'} kg',
                                  fontSize: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DetailRow(
                                  label: 'Date',
                                  value: formattedDate,
                                  fontSize: 12,
                                ),
                                if (isAccepted || isCompleted) ...[
                                  const SizedBox(height: 4),
                                  DetailRow(
                                    label: 'Agent',
                                    value: request['agent']?['username']?.toString() ?? 'N/A',
                                    fontSize: 12,
                                  ),
                                  const SizedBox(height: 4),
                                  DetailRow(
                                    label: 'Agent Phone',
                                    value: request['agent']?['phone']?.toString() ?? 'N/A',
                                    fontSize: 12,
                                  ),
                                ],
                                if (isAccepted) ...[
                                  const SizedBox(height: 4),
                                  DetailRow(
                                    label: 'Est. Arrival',
                                    value: request['estimatedArrival'] != null
                                        ? DateFormat('dd MMM, HH:mm')
                                            .format(DateTime.parse(request['estimatedArrival']).toLocal())
                                        : 'N/A',
                                    fontSize: 12,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isSelectionMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((isCancelled && (_selectedStatus == 'All' || _selectedStatus.toLowerCase() == 'cancelled')))
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 14),
                            onPressed: _deleteSelectedRequests,
                            tooltip: 'Delete Request',
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                          ),
                        if ((isPending && (_selectedStatus == 'All' || _selectedStatus.toLowerCase() == 'pending')) ||
                            (isAccepted && (_selectedStatus == 'All' || _selectedStatus.toLowerCase() == 'accepted')))
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.orange, size: 14),
                            onPressed: _cancelSelectedRequests,
                            tooltip: 'Cancel Request',
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                          ),
                        if (_selectedIndices.contains(index))
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 14),
                            onPressed: () {
                              setState(() {
                                _selectedIndices.remove(index);
                                if (_selectedIndices.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              });
                            },
                            tooltip: 'Uncheck',
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                if (!_isSelectionMode)
                  const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchRequests,
      color: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
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
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              style: AppTheme.bodyTextStyle.copyWith(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search by agent name...',
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
                            items: _recyclableTypes.map((type) => DropdownMenuItem<String>(
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
                          onPressed: _fetchRequests,
                          tooltip: 'Refresh',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total: ${_filteredRequests.length}',
                          style: AppTheme.bodyTextStyle.copyWith(
                            fontSize: 14,
                            color: AppTheme.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
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
                        if (_lastRefreshed.isNotEmpty)
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
                        if (_filteredRequests.any((request) => request['status']?.toLowerCase() == 'completed'))
                          CustomButton(
                            onPressed: _clearCompletedRequests,
                            color: Colors.redAccent,
                            child: const Text(
                              'Clear Completed',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3))
                    : _errorMessage != null
                        ? Center(
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
                                  onPressed: _fetchRequests,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh, size: 18, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text("Retry", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredRequests.isEmpty
                            ? Center(
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
                              )
                            : AnimationLimiter(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredRequests.length,
                                  itemBuilder: (context, index) {
                                    final request = _filteredRequests[index];
                                    return AnimationConfiguration.staggeredList(
                                      position: index,
                                      duration: const Duration(milliseconds: 375),
                                      child: SlideAnimation(
                                        verticalOffset: 50.0,
                                        child: FadeInAnimation(child: _buildRequestTile(request, index)),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
          if (_isSelectionMode)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_selectedStatus != 'All')
                    CustomButton(
                      onPressed: _toggleSelectAll,
                      isMini: true,
                      child: Icon(
                        _selectAll ? Icons.check_box : Icons.check_box_outline_blank,
                        color: Colors.white,
                      ),
                    ),
                  if (_selectedIndices.any((index) => _filteredRequests[index]['status']?.toLowerCase() == 'completed'))
                    CustomButton(
                      onPressed: _deleteSelectedRequests,
                      color: Colors.redAccent,
                      isMini: true,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                  if (_selectedIndices.any((index) => _filteredRequests[index]['status']?.toLowerCase() == 'accepted'))
                    CustomButton(
                      onPressed: _cancelSelectedRequests,
                      color: Colors.orange,
                      isMini: true,
                      child: const Icon(Icons.cancel, color: Colors.white),
                    ),
                  if (_selectedStatus != 'All' && _selectedIndices.isNotEmpty)
                    CustomButton(
                      onPressed: _deleteSelectedRequests,
                      color: Colors.redAccent,
                      isMini: true,
                      child: const Icon(Icons.delete_forever, color: Colors.white),
                    ),
                  CustomButton(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedIndices.clear();
                        _selectAll = false;
                      });
                    },
                    isMini: true,
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}