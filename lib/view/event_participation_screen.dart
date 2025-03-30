import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';

class EventParticipationScreen extends StatefulWidget {
  const EventParticipationScreen({super.key});

  @override
  State<EventParticipationScreen> createState() => _EventParticipationScreenState();
}

class _EventParticipationScreenState extends State<EventParticipationScreen> with AutomaticKeepAliveClientMixin {
  List<dynamic> _events = [];
  List<dynamic> _filteredEvents = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final Map<int, bool> _expandedDescriptions = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _searchController.addListener(_filterEvents);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {});
          print('EventParticipationScreen: Notification received, refreshing UI');
        },
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleApiCall<http.Response>(
      context,
      () => AuthService.makeRequest('GET', 'events'),
      defaultErrorMessage: 'Failed to fetch events',
      onSuccess: (response) {
        print('EventParticipationScreen: Fetch events response: ${response.statusCode} - ${response.body}');
        if (response.body.isEmpty || response.body.trim().toLowerCase() == 'null') {
          throw Exception('Received empty or invalid response from server');
        }
        try {
          final data = jsonDecode(response.body);
          if (data['success']) {
            setState(() {
              _events = data['events'].map((event) {
                if (event['participantCount'] != null) {
                  event['participantCount'] = int.tryParse(event['participantCount'].toString()) ?? 0;
                } else {
                  event['participantCount'] = 0;
                }
                return event;
              }).toList();
              _filteredEvents = _events;
            });
            print('EventParticipationScreen: Fetched ${_events.length} events');
          } else {
            throw Exception(data['message'] ?? 'Failed to fetch events');
          }
        } catch (e) {
          print('EventParticipationScreen: Error parsing fetch events response: $e');
          throw Exception('Failed to parse events response: $e');
        }
      },
      onError: (error) {
        setState(() {
          _errorMessage = error.toString();
        });
        print('EventParticipationScreen: Error fetching events: $error');
      },
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _filterEvents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEvents = _events.where((event) {
        final title = event['title'].toString().toLowerCase();
        final location = event['location'].toString().toLowerCase();
        final eventDate = DateTime.parse(event['date']);
        bool matchesQuery = title.contains(query) || location.contains(query);
        bool matchesDate = true;
        if (_startDate != null) {
          matchesDate = eventDate.isAfter(_startDate!) || eventDate.isAtSameMomentAs(_startDate!);
        }
        if (_endDate != null) {
          matchesDate = matchesDate && (eventDate.isBefore(_endDate!.add(const Duration(days: 1))) || eventDate.isAtSameMomentAs(_endDate!));
        }
        return matchesQuery && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.backgroundColor,
              onSurface: AppTheme.textColor,
            ),
            dialogBackgroundColor: AppTheme.cardColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterEvents();
    }
  }

  Future<void> _joinEvent(String eventId) async {
    await ExceptionHandling.handleApiCall<http.Response>(
      context,
      () => AuthService.makeRequest('POST', 'events/$eventId/participate'),
      defaultErrorMessage: 'Failed to join event',
      onSuccess: (response) {
        print('EventParticipationScreen: Join event response: ${response.statusCode} - ${response.body}');
        if (response.body.isEmpty || response.body.trim().toLowerCase() == 'null') {
          throw Exception('Received empty or invalid response from server');
        }
        try {
          final data = jsonDecode(response.body);
          if (data['success']) {
            ExceptionHandling.showSnackBar(context, 'Successfully joined the event!');
            _fetchEvents();
            print('EventParticipationScreen: Successfully joined event $eventId');
          } else {
            throw Exception(data['message'] ?? 'Failed to join event');
          }
        } catch (e) {
          print('EventParticipationScreen: Error parsing join event response: $e');
          throw Exception('Failed to parse join event response: $e');
        }
      },
      onError: (error) {
        ExceptionHandling.showSnackBar(context, error.toString());
        print('EventParticipationScreen: Error joining event: $error');
      },
    );
  }

  Future<void> _leaveEvent(String eventId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Leave Event',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to leave this event?',
          style: AppTheme.bodyTextStyle.copyWith(
            color: AppTheme.secondaryTextColor,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyTextStyle.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave',
              style: AppTheme.bodyTextStyle.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ExceptionHandling.handleApiCall<http.Response>(
      context,
      () => AuthService.makeRequest('DELETE', 'events/$eventId/participate'),
      defaultErrorMessage: 'Failed to leave event',
      onSuccess: (response) {
        print('EventParticipationScreen: Leave event response: ${response.statusCode} - ${response.body}');
        if (response.body.isEmpty || response.body.trim().toLowerCase() == 'null') {
          throw Exception('Received empty or invalid response from server');
        }
        try {
          final data = jsonDecode(response.body);
          if (data['success']) {
            ExceptionHandling.showSnackBar(context, 'Successfully left the event!');
            _fetchEvents();
            print('EventParticipationScreen: Successfully left event $eventId');
          } else {
            throw Exception(data['message'] ?? 'Failed to leave event');
          }
        } catch (e) {
          print('EventParticipationScreen: Error parsing leave event response: $e');
          throw Exception('Failed to parse leave event response: $e');
        }
      },
      onError: (error) {
        ExceptionHandling.showSnackBar(context, error.toString());
        print('EventParticipationScreen: Error leaving event: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Event Participation',
        isAgentScreen: false,
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {});
          print('EventParticipationScreen: Notification state changed, refreshing UI');
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
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: 16.0,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by title or location...',
                        hintStyle: AppTheme.bodyTextStyle.copyWith(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.primaryColor,
                        ),
                        filled: true,
                        fillColor: AppTheme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: AppTheme.bodyTextStyle.copyWith(
                        color: AppTheme.textColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.filter_alt,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () => _selectDateRange(context),
                    tooltip: 'Filter by Date',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.history,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.eventsHistory);
                      print('EventParticipationScreen: Navigated to Events History');
                    },
                    tooltip: 'Event History',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_startDate != null && _endDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'From: ${DateFormat('MMM dd, yyyy').format(_startDate!)}',
                        style: AppTheme.bodyTextStyle.copyWith(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'To: ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                        style: AppTheme.bodyTextStyle.copyWith(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _filterEvents();
                        },
                        tooltip: 'Clear Date Filter',
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: AppTheme.bodyTextStyle.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchEvents,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Retry',
                                    style: AppTheme.bodyTextStyle.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredEvents.isEmpty
                            ? Center(
                                child: Text(
                                  'No events found.',
                                  style: AppTheme.bodyTextStyle.copyWith(
                                    color: AppTheme.secondaryTextColor,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _filteredEvents[index];
                                  final eventDate = DateTime.parse(event['date']);
                                  final formattedDate = DateFormat('MMM dd, yyyy – hh:mm a').format(eventDate);
                                  final isExpanded = _expandedDescriptions[event['id']] ?? false;
                                  final participantCount = event['participantCount'] as int;

                                  return Card(
                                    elevation: 5,
                                    margin: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white,
                                            Colors.grey.shade100,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.2),
                                            spreadRadius: 2,
                                            blurRadius: 5,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    event['title'],
                                                    style: GoogleFonts.playfairDisplay(
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppTheme.textColor,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Stack(
                                                      children: [
                                                        const CircleAvatar(
                                                          radius: 15,
                                                          backgroundColor: Colors.blueAccent,
                                                          child: Text(
                                                            'A',
                                                            style: TextStyle(color: Colors.white, fontSize: 12),
                                                          ),
                                                        ),
                                                        Transform.translate(
                                                          offset: const Offset(20, 0),
                                                          child: const CircleAvatar(
                                                            radius: 15,
                                                            backgroundColor: Colors.green,
                                                            child: Text(
                                                              'B',
                                                              style: TextStyle(color: Colors.white, fontSize: 12),
                                                            ),
                                                          ),
                                                        ),
                                                        Transform.translate(
                                                          offset: const Offset(40, 0),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(2),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: Colors.grey.shade300,
                                                            ),
                                                            child: CircleAvatar(
                                                              radius: 13,
                                                              backgroundColor: Colors.grey.shade400,
                                                              child: Text(
                                                                '+${participantCount > 2 ? (participantCount - 2) : 0}',
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '$participantCount',
                                                      style: AppTheme.bodyTextStyle.copyWith(
                                                        color: AppTheme.primaryColor,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.people,
                                                      color: AppTheme.primaryColor,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today,
                                                  color: Colors.blueAccent,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  formattedDate,
                                                  style: AppTheme.bodyTextStyle.copyWith(
                                                    color: AppTheme.secondaryTextColor,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on,
                                                  color: Colors.redAccent,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    event['location'],
                                                    style: AppTheme.bodyTextStyle.copyWith(
                                                      color: AppTheme.secondaryTextColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (event['description'] != null && event['description'].isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.description,
                                                    color: Colors.purpleAccent,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      event['description'],
                                                      style: AppTheme.bodyTextStyle.copyWith(
                                                        color: AppTheme.textColor,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: isExpanded ? null : 2,
                                                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              TextButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _expandedDescriptions[event['id']] = !isExpanded;
                                                  });
                                                },
                                                child: Text(
                                                  isExpanded ? 'Show Less' : 'Show More',
                                                  style: AppTheme.bodyTextStyle.copyWith(
                                                    color: AppTheme.primaryColor,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: ElevatedButton.icon(
                                                icon: Icon(
                                                  (event['participantCount'] ?? 0) > 0 ? Icons.exit_to_app : Icons.add,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                                label: FutureBuilder<bool>(
                                                  future: _checkParticipation(event['id']),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                                      return const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      );
                                                    }
                                                    final isParticipating = snapshot.data ?? false;
                                                    return Text(
                                                      isParticipating ? 'Leave Event' : 'Join Event',
                                                      style: AppTheme.bodyTextStyle.copyWith(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                onPressed: eventDate.isBefore(DateTime.now())
                                                    ? null
                                                    : () async {
                                                        final isParticipating = await _checkParticipation(event['id']);
                                                        if (isParticipating) {
                                                          await _leaveEvent(event['id'].toString());
                                                        } else {
                                                          await _joinEvent(event['id'].toString());
                                                        }
                                                      },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  disabledBackgroundColor: AppTheme.secondaryTextColor.withOpacity(0.5),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkParticipation(int eventId) async {
    try {
      final response = await AuthService.makeRequest('GET', 'events/$eventId');
      print('EventParticipationScreen: Check participation response: ${response.statusCode} - ${response.body}');
      if (response.body.isEmpty || response.body.trim().toLowerCase() == 'null') {
        print('EventParticipationScreen: Check participation: Received empty or invalid response');
        return false;
      }
      final data = jsonDecode(response.body);
      if (data['success']) {
        final participants = data['event']['participants'] as List<dynamic>;
        final userProfile = await AuthService.getUserProfile();
        final userId = userProfile['user']['id'];
        return participants.any((participant) => participant['userId'] == userId);
      }
      print('EventParticipationScreen: Check participation: Success is false - ${data['message']}');
      return false;
    } catch (e) {
      print('EventParticipationScreen: Check participation error: $e');
      return false;
    }
  }
}// 16596
// 15189
// 18870
// 27059
// 31433
// 10021
