import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:lottie/lottie.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/widgets/custom_button.dart';
import 'package:recycle_riti/widgets/section_tile.dart';

class SchedulePickupTab extends StatefulWidget {
  const SchedulePickupTab({super.key});

  @override
  State<SchedulePickupTab> createState() => _SchedulePickupTabState();
}

class _SchedulePickupTabState extends State<SchedulePickupTab> {
  String _frequency = "One-Time";
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _recyclableType;
  final TextEditingController _quantityController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _quantityError;
  List<Map<String, dynamic>> _recyclableTypes = [];
  bool _isFetchingTypes = true;
  double? _selectedLat;
  double? _selectedLng;
  final flutter_map.MapController _mapController = flutter_map.MapController();
  bool _isMapReady = false;
  bool _hasMapRendered = false; // New flag to track if the map has rendered

  @override
  void initState() {
    super.initState();
    _fetchRecyclableTypes();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecyclableTypes() async {
    setState(() {
      _isFetchingTypes = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.getRecyclableTypes(),
      defaultErrorMessage: 'Failed to fetch recyclable types',
      onSuccess: (response) {
        setState(() {
          _recyclableTypes = List<Map<String, dynamic>>.from(response['types']);
          if (_recyclableTypes.isNotEmpty) _recyclableType = _recyclableTypes[0]['name'];
        });
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
        });
      },
    );

    setState(() {
      _isFetchingTypes = false;
    });
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please enable it in settings.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Please enable it in settings.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
        _isMapReady = true; // Indicate that we're ready to render the map
      });

      // Move map to the user's location only after the map has rendered
      if (_hasMapRendered && _selectedLat != null && _selectedLng != null) {
        _mapController.move(latlng.LatLng(_selectedLat!, _selectedLng!), 15);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _selectedLat = 27.7172; // Fallback to Kathmandu if location fails
        _selectedLng = 85.3240;
        _isMapReady = true; // Allow map to render even if location fetch fails
      });
      ExceptionHandling.showSnackBar(context, 'Failed to fetch location: $_errorMessage');
    }
  }

  void _clearForm() {
    setState(() {
      _frequency = "One-Time";
      _selectedDate = null;
      _selectedTime = null;
      _recyclableType = _recyclableTypes.isNotEmpty ? _recyclableTypes[0]['name'] : null;
      _quantityController.clear();
      _quantityError = null;
      _errorMessage = null;
    });
    _fetchCurrentLocation();
    ExceptionHandling.showSnackBar(context, 'Form cleared successfully');
  }

  void _toggleFullMapView() {
    final fullMapController = flutter_map.MapController();
    double fullMapLat = _selectedLat ?? 27.7172;
    double fullMapLng = _selectedLng ?? 85.3240;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.9),
                  child: flutter_map.FlutterMap(
                    mapController: fullMapController,
                    options: flutter_map.MapOptions(
                      initialCenter: latlng.LatLng(fullMapLat, fullMapLng),
                      initialZoom: 15,
                      minZoom: 5,
                      maxZoom: 20,
                      onTap: (tapPosition, point) {
                        setDialogState(() {
                          fullMapLat = point.latitude;
                          fullMapLng = point.longitude;
                        });
                        setState(() {
                          _selectedLat = point.latitude;
                          _selectedLng = point.longitude;
                        });
                        fullMapController.move(latlng.LatLng(fullMapLat, fullMapLng), 18);
                      },
                      onMapReady: () {
                        fullMapController.move(latlng.LatLng(fullMapLat, fullMapLng), 15);
                      },
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
                            point: latlng.LatLng(fullMapLat, fullMapLng),
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
                  left: 10,
                  child: CustomButton(
                    onPressed: _fetchCurrentLocation,
                    isMini: true,
                    child: const Icon(Icons.my_location, color: Colors.white),
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
            );
          },
        ),
      ),
    ).whenComplete(() {
      fullMapController.dispose();
      setState(() {
        if (_selectedLat != null && _selectedLng != null && _hasMapRendered) {
          _mapController.move(latlng.LatLng(_selectedLat!, _selectedLng!), 15);
        }
      });
    });
  }

  DateTime? _combineDateAndTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _submitPickupRequest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _quantityError = null;
    });

    try {
      final pickupDateTime = _combineDateAndTime();
      if (pickupDateTime == null) {
        throw Exception('Please select both date and time');
      }

      final quantityText = _quantityController.text.trim();
      if (quantityText.isEmpty) {
        throw Exception('Please enter the quantity');
      }
      final quantity = int.tryParse(quantityText);
      if (quantity == null || quantity <= 0) {
        setState(() {
          _quantityError = 'Quantity must be a positive integer';
        });
        throw Exception('Quantity must be a positive integer');
      }

      if (_recyclableType == null) {
        throw Exception('Please select a recyclable type');
      }
      final typeId = _recyclableTypes.firstWhere(
        (type) => type['name'] == _recyclableType,
        orElse: () => throw Exception('Invalid recyclable type selected'),
      )['id'];

      if (_selectedLat == null || _selectedLng == null) {
        throw Exception('Please select a location on the map');
      }

      final location = 'lat:$_selectedLat,lng:$_selectedLng';

      final response = await AuthService.schedulePickup({
        'recyclableTypeId': typeId,
        'quantity': quantity,
        'pickupDate': pickupDateTime.toIso8601String(),
        'frequency': _frequency,
        'location': location,
      });

      final requestId = response['pickupRequest']?['id']?.toString();
      if (requestId == null) {
        throw Exception('Failed to retrieve request ID from response');
      }

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.pickupConfirmation,
        arguments: {'requestId': requestId},
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      ExceptionHandling.showSnackBar(context, _errorMessage!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isFetchingTypes) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3));
    }

    if (_errorMessage != null && _recyclableTypes.isEmpty) {
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
              onPressed: _fetchRecyclableTypes,
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
      );
    }

    if (_recyclableTypes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No recyclable types available', style: AppTheme.bodyTextStyle.copyWith(color: Colors.grey)),
            const SizedBox(height: 20),
            CustomButton(
              onPressed: _fetchRecyclableTypes,
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
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          AnimationLimiter(
            child: AnimationConfiguration.staggeredList(
              position: 0,
              duration: const Duration(milliseconds: 600),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildHeaderSection(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Form Fields
          AnimationLimiter(
            child: AnimationConfiguration.staggeredList(
              position: 1,
              duration: const Duration(milliseconds: 600),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildFormFields(screenWidth),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Location Preview
          _buildLocationPreview(),
          const SizedBox(height: 20),

          // Error and Submit Section
          AnimationLimiter(
            child: AnimationConfiguration.staggeredList(
              position: 2,
              duration: const Duration(milliseconds: 600),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildErrorAndSubmitSection(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Center(
          child: SizedBox(
            height: 150,
            width: 250,
            child: Lottie.network(
              'https://lottie.host/e254f8e4-11a1-4f59-be80-8ad899382cad/cWHRTmHfC4.json',
              fit: BoxFit.contain,
              onLoaded: (composition) => print('Lottie animation loaded'),
              errorBuilder: (context, error, stackTrace) {
                print('Error loading Lottie animation: $error');
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.redAccent, size: 50),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load animation',
                      style: AppTheme.bodyTextStyle.copyWith(color: Colors.redAccent),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Schedule a pickup at your convenience",
          style: AppTheme.bodyTextStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: AppTheme.textColor,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormFields(double screenWidth) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppTheme.primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: "Recyclable Type"),
            const SizedBox(height: 8),
            _buildDropdownField(
              value: _recyclableType,
              items: _recyclableTypes.map((type) => type['name'] as String).toList(),
              onChanged: (value) => setState(() => _recyclableType = value),
            ),
            const SizedBox(height: 16),

            const SectionTitle(title: "Quantity (kg)"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _quantityController,
              hintText: "Enter quantity in kg",
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _quantityError = null;
                });
              },
            ),
            if (_quantityError != null) ...[
              const SizedBox(height: 8),
              Text(
                _quantityError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),

            const SectionTitle(title: "Pickup Date & Time"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                        builder: (context, child) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.primaryColor,
                              onPrimary: Colors.white,
                            ),
                            textTheme: const TextTheme(
                              bodyLarge: TextStyle(fontSize: 16),
                              bodyMedium: TextStyle(fontSize: 14),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (pickedDate != null) setState(() => _selectedDate = pickedDate);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _selectedDate != null
                                ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                                : "Select Date",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.primaryColor,
                              onPrimary: Colors.white,
                            ),
                            textTheme: const TextTheme(
                              bodyLarge: TextStyle(fontSize: 16),
                              bodyMedium: TextStyle(fontSize: 14),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (pickedTime != null) setState(() => _selectedTime = pickedTime);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _selectedTime != null ? _selectedTime!.format(context) : "Select Time",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const SectionTitle(title: "Frequency"),
            const SizedBox(height: 8),
            _buildDropdownField(
              value: _frequency,
              items: const ["One-Time", "Daily", "Weekly", "Monthly"],
              onChanged: (value) => setState(() => _frequency = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPreview() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppTheme.primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              _isMapReady && _selectedLat != null && _selectedLng != null
                  ? flutter_map.FlutterMap(
                      mapController: _mapController,
                      options: flutter_map.MapOptions(
                        initialCenter: latlng.LatLng(_selectedLat!, _selectedLng!),
                        initialZoom: 15,
                        minZoom: 5,
                        maxZoom: 20,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLat = point.latitude;
                            _selectedLng = point.longitude;
                            if (_hasMapRendered) {
                              _mapController.move(latlng.LatLng(_selectedLat!, _selectedLng!), 18);
                            }
                          });
                        },
                        onMapReady: () {
                          setState(() {
                            _hasMapRendered = true; // Mark that the map has rendered
                          });
                          // Now safe to move the map
                          if (_selectedLat != null && _selectedLng != null) {
                            _mapController.move(latlng.LatLng(_selectedLat!, _selectedLng!), 15);
                          }
                        },
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
                              point: latlng.LatLng(_selectedLat!, _selectedLng!),
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
                  : const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
              Positioned(
                top: 10,
                right: 10,
                child: CustomButton(
                  onPressed: _fetchCurrentLocation,
                  isMini: true,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: CustomButton(
                  onPressed: _toggleFullMapView,
                  isMini: true,
                  child: const Icon(Icons.fullscreen, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorAndSubmitSection() {
    return Column(
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CustomButton(
              onPressed: _clearForm,
              color: Colors.redAccent,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "Clear",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _isLoading
                ? const CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3)
                : CustomButton(
                    onPressed: _submitPickupRequest,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Schedule",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    String? hintText,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: AppTheme.bodyTextStyle.copyWith(
        color: AppTheme.textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: AppTheme.bodyTextStyle.copyWith(
                  color: AppTheme.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      style: AppTheme.bodyTextStyle.copyWith(
        color: AppTheme.textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
    );
  }
}// 20275
