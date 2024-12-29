import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/services/image_service.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/edit_profile.dart';

class ProfileHeader extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userPhone;
  final String? profileImageUrl;
  final VoidCallback onRefresh;

  const ProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.profileImageUrl,
    required this.onRefresh,
  });

  @override
  _ProfileHeaderState createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  File? _imageFile;
  bool _isUploadingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImageService.pickImage(source);
    if (file == null) {
      ExceptionHandling.showSnackBar(context, 'No image selected or unsupported format (only JPG, JPEG, PNG allowed)');
      return;
    }

    setState(() {
      _imageFile = file;
    });
    await _uploadProfileImage();
  }

  Future<void> _uploadProfileImage() async {
    if (_imageFile == null) {
      ExceptionHandling.showSnackBar(context, 'No image selected');
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Validate file exists
      if (!await _imageFile!.exists()) {
        throw Exception('Image file does not exist: ${_imageFile!.path}');
      }

      // Compress the image with a lower quality to reduce size
      final compressedFile = await ImageService.compressImage(_imageFile!, quality: 30);
      if (compressedFile == null) {
        throw Exception('Failed to compress image');
      }

      // Check file size after compression (limit to 1MB)
      final fileSizeInBytes = await compressedFile.length();
      const maxSizeInBytes = 1 * 1024 * 1024; // 1MB
      if (fileSizeInBytes > maxSizeInBytes) {
        throw Exception('Image size too large after compression (${fileSizeInBytes ~/ 1024} KB). Please select a smaller image.');
      }

      await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
        context,
        () => AuthService.uploadProfileImage(compressedFile),
        defaultErrorMessage: 'Failed to upload image. Please try again.',
        retryCallback: _uploadProfileImage,
        onSuccess: (response) {
          if (widget.profileImageUrl != null) {
            CachedNetworkImage.evictFromCache(widget.profileImageUrl!);
          }
          widget.onRefresh();
          ExceptionHandling.showSnackBar(context, 'Profile image updated successfully');
        },
        onError: (error) {},
      );
    } catch (e) {
      ExceptionHandling.showSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _imageFile = null;
        });
      }
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardColor,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Update Profile Picture",
              style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
            ),
            const SizedBox(height: 16),
            _buildDialogOption(
              icon: Icons.camera_alt,
              title: "Take a Picture",
              onTap: () async {
                await _pickImage(ImageSource.camera);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            _buildDialogOption(
              icon: Icons.image,
              title: "Upload from Gallery",
              onTap: () async {
                await _pickImage(ImageSource.gallery);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            _buildDialogOption(
              icon: Icons.cancel,
              title: "Cancel",
              iconColor: Colors.redAccent,
              textColor: Colors.redAccent,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.green,
    Color textColor = Colors.black,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppTheme.bodyTextStyle.copyWith(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8, spreadRadius: 2),
                      ],
                    ),
                    child: ClipOval(
                      child: widget.profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.profileImageUrl!,
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Image.asset(
                                'assets/images/placeholder.png',
                                fit: BoxFit.cover,
                                width: 90,
                                height: 90,
                              ),
                            )
                          : Image.asset(
                              'assets/images/placeholder.png',
                              fit: BoxFit.cover,
                              width: 90,
                              height: 90,
                            ),
                    ),
                  ),
                  if (_isUploadingImage)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        if (!_isUploadingImage) {
                          _showImagePickerDialog();
                        }
                      },
                      child: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        radius: 16,
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: AppTheme.sectionTitleStyle.copyWith(fontSize: 22),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Recycler",
                    style: AppTheme.bodyTextStyle.copyWith(fontSize: 14, color: AppTheme.secondaryTextColor),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.phone, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.userPhone,
                          style: AppTheme.bodyTextStyle.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.userEmail,
                          style: AppTheme.bodyTextStyle.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                      ).then((_) => widget.onRefresh());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0, // No shadow
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "Edit Profile",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}// 721
