// lib/view/edit_profile.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';
import 'package:recycle_riti/widgets/custom_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  String? name;
  String? email;
  String? phone;
  String? imgUrl;
  File? imgFile;
  bool isLoading = false;
  bool isImgLoading = false;
  String? _userRole; // Added to determine if user is an agent
  final picker = ImagePicker();

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
    // Initialize notifications (EditProfileScreen is one of the specified screens)
    NotificationScreen.initNotifications(context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () async {
        final token = await AuthService.getAccessToken();
        if (token == null || token.isEmpty) {
          throw Exception('No access token found. Please log in.');
        }
        return await AuthService.getUserProfile();
      },
      defaultErrorMessage: 'Failed to load user data',
      retryCallback: _fetchData,
      onSuccess: (data) {
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Failed to fetch user profile');
        }
        if (mounted) {
          setState(() {
            name = data['user']['username'] ?? 'User Name';
            email = data['user']['email'] ?? 'useremail@example.com';
            phone = data['user']['phone'];
            _userRole = data['user']['role']?.toString().toLowerCase(); // Fetch user role
            String? profileImagePath = data['user']['profileImage'];
            if (profileImagePath != null) {
              profileImagePath = profileImagePath.replaceFirst('/uploads/', '');
              imgUrl =
                  '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$profileImagePath?t=${DateTime.now().millisecondsSinceEpoch}';
            } else {
              imgUrl = null;
            }
            print('Profile image URL: $imgUrl');
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (cameraStatus.isPermanentlyDenied) {
            ExceptionHandling.showSnackBar(context, 'Camera permission is permanently denied. Please enable it in settings.');
            await openAppSettings();
            return false;
          }
          ExceptionHandling.showSnackBar(context, 'Camera permission is required to take a picture.');
          return false;
        }
      }
    } else {
      // For gallery access, request media permissions based on platform
      if (Platform.isAndroid) {
        // On Android 13+ (API 33+), request granular media permissions
        if (Platform.version.split('.').first.compareTo('33') >= 0) {
          // Request photos permission (covers images)
          var photosStatus = await Permission.photos.status;
          if (!photosStatus.isGranted) {
            photosStatus = await Permission.photos.request();
            if (!photosStatus.isGranted) {
              if (photosStatus.isPermanentlyDenied) {
                ExceptionHandling.showSnackBar(context, 'Photo access permission is permanently denied. Please enable it in settings.');
                await openAppSettings();
                return false;
              }
              ExceptionHandling.showSnackBar(context, 'Photo access permission is required to select an image from the gallery.');
              return false;
            }
          }
        } else {
          // On Android 12 and below, request storage permission
          var storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) {
              if (storageStatus.isPermanentlyDenied) {
                ExceptionHandling.showSnackBar(context, 'Storage permission is permanently denied. Please enable it in settings.');
                await openAppSettings();
                return false;
              }
              ExceptionHandling.showSnackBar(context, 'Storage permission is required to access the gallery.');
              return false;
            }
          }
        }
      } else if (Platform.isIOS) {
        // On iOS, request photos permission
        var photosStatus = await Permission.photos.status;
        if (!photosStatus.isGranted) {
          photosStatus = await Permission.photos.request();
          if (!photosStatus.isGranted) {
            if (photosStatus.isPermanentlyDenied) {
              ExceptionHandling.showSnackBar(context, 'Photo access permission is permanently denied. Please enable it in settings.');
              await openAppSettings();
              return false;
            }
            ExceptionHandling.showSnackBar(context, 'Photo access permission is required to select an image from the gallery.');
            return false;
          }
        }
      }
    }
    return true;
  }

  Future<void> _pickImage(ImageSource src) async {
    int retryCount = 0;
    const maxRetries = 2;
    while (retryCount < maxRetries) {
      bool hasPermission = await _requestPermissions(src);
      if (!hasPermission) {
        retryCount++;
        if (retryCount >= maxRetries) {
          ExceptionHandling.showSnackBar(context, 'Failed to obtain permission after $maxRetries attempts.');
          return;
        }
        await Future.delayed(Duration(seconds: 1));
        continue;
      }

      try {
        final pickedFile = await picker.pickImage(source: src);
        if (pickedFile == null) {
          ExceptionHandling.showSnackBar(context, 'No image selected');
          return;
        }

        final file = File(pickedFile.path);
        final ext = path.extension(pickedFile.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
          ExceptionHandling.showSnackBar(context, 'Only JPG, JPEG, and PNG files are allowed');
          return;
        }

        if (mounted) {
          setState(() {
            imgFile = file;
          });
          await _uploadImg();
        }
        return;
      } catch (e) {
        print('Error picking image: $e');
        retryCount++;
        if (retryCount >= maxRetries) {
          ExceptionHandling.showSnackBar(context, 'Failed to pick image after $maxRetries attempts: ${e.toString().replaceFirst('Exception: ', '')}');
          return;
        }
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  Future<void> _uploadImg() async {
    if (imgFile == null) {
      ExceptionHandling.showSnackBar(context, 'No image selected');
      return;
    }

    setState(() {
      isImgLoading = true;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () async {
        final originalSize = await imgFile!.length();
        print('Original image size: ${originalSize ~/ 1024} KB');

        final compressedPath = '${imgFile!.path}_compressed.jpg';
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imgFile!.path,
          compressedPath,
          quality: 30,
          format: CompressFormat.jpeg,
        );
        if (compressedFile == null) {
          throw Exception('Failed to compress image');
        }

        final compressedSize = await File(compressedFile.path).length();
        print('Compressed image size: ${compressedSize ~/ 1024} KB');

        const maxSizeInBytes = 1 * 1024 * 1024;
        if (compressedSize > maxSizeInBytes) {
          throw Exception('Image size too large after compression (${compressedSize ~/ 1024} KB). Please select a smaller image.');
        }

        return await AuthService.uploadProfileImage(File(compressedFile.path));
      },
      defaultErrorMessage: 'Failed to upload image',
      retryCallback: _uploadImg,
      onSuccess: (res) {
        if (res['success'] != true) {
          throw Exception(res['message'] ?? 'Image upload failed');
        }
        ExceptionHandling.showSnackBar(context, 'Image updated successfully');
        if (imgUrl != null) {
          CachedNetworkImage.evictFromCache(imgUrl!);
          print('Cleared cache for: $imgUrl');
        }
        _fetchData();
        setState(() {
          imgFile = null;
        });
      },
    );

    setState(() {
      isImgLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.updateProfile(
        username: name,
        phone: phone,
        email: email,
      ),
      defaultErrorMessage: 'Failed to update profile',
      onSuccess: (res) {
        if (res['success'] != true) {
          throw Exception(res['message'] ?? 'Profile update failed');
        }
        ExceptionHandling.showSnackBar(context, 'Profile updated successfully');
        Navigator.pop(context);
      },
    );

    setState(() {
      isLoading = false;
    });
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Update Profile Picture",
                style: AppTheme.sectionTitleStyle.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                title: Text(
                  "Take a Picture",
                  style: AppTheme.bodyTextStyle,
                ),
                onTap: () async {
                  await _pickImage(ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: AppTheme.primaryColor),
                title: Text(
                  "Upload from Gallery",
                  style: AppTheme.bodyTextStyle,
                ),
                onTap: () async {
                  await _pickImage(ImageSource.gallery);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.redAccent),
                title: Text(
                  "Cancel",
                  style: AppTheme.bodyTextStyle.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Edit Profile",
        isAgentScreen: _userRole == 'agent',
        showNotifications: true, // Enable notifications for EditProfileScreen
        onNotificationStateChanged: () {
          setState(() {}); // Refresh the badge count when notifications change
        },
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  onRefresh: _fetchData,
                  color: AppTheme.primaryColor,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primaryColor,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: isImgLoading
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              color: AppTheme.primaryColor,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : imgFile != null
                                            ? Image.file(
                                                imgFile!,
                                                fit: BoxFit.cover,
                                                width: 120,
                                                height: 120,
                                              )
                                            : imgUrl != null
                                                ? CachedNetworkImage(
                                                    imageUrl: imgUrl!,
                                                    placeholder: (context, url) =>
                                                        const CircularProgressIndicator(
                                                      color: AppTheme.primaryColor,
                                                      strokeWidth: 2,
                                                    ),
                                                    errorWidget: (context, url, error) {
                                                      print('Error loading profile image: $error');
                                                      return Image.asset(
                                                        'assets/images/placeholder.png',
                                                        fit: BoxFit.cover,
                                                        width: 120,
                                                        height: 120,
                                                      );
                                                    },
                                                    fit: BoxFit.cover,
                                                    width: 120,
                                                    height: 120,
                                                  )
                                                : Image.asset(
                                                    'assets/images/placeholder.png',
                                                    fit: BoxFit.cover,
                                                    width: 120,
                                                    height: 120,
                                                  ),
                                  ),
                                ),
                                if (isImgLoading)
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black54,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primaryColor,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!isImgLoading) {
                                        _showImagePicker(context);
                                      }
                                    },
                                    child: CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor,
                                      radius: 18,
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: AppTheme.cardColor,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Edit Your Details",
                                    style: AppTheme.sectionTitleStyle.copyWith(
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    initialValue: name,
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppTheme.primaryColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[400]!),
                                      ),
                                      labelStyle: const TextStyle(color: Colors.grey),
                                    ),
                                    onChanged: (value) => name = value,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Full name required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    initialValue: email,
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppTheme.primaryColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[400]!),
                                      ),
                                      labelStyle: const TextStyle(color: Colors.grey),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (value) => email = value,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Email required';
                                      }
                                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    initialValue: phone,
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppTheme.primaryColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[400]!),
                                      ),
                                      labelStyle: const TextStyle(color: Colors.grey),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    onChanged: (value) => phone = value,
                                  ),
                                  const SizedBox(height: 30),
                                  CustomButton(
                                    onPressed: _updateProfile,
                                    child: const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}// 27474
// 10976
// 30292
// 31013
