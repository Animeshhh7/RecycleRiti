import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<bool> requestPermissions(ImageSource source) async {
    int retryCount = 0;
    const maxRetries = 3;
    while (retryCount < maxRetries) {
      try {
        if (source == ImageSource.camera) {
          var cameraStatus = await Permission.camera.status;
          if (!cameraStatus.isGranted) {
            cameraStatus = await Permission.camera.request();
            if (!cameraStatus.isGranted) {
              if (cameraStatus.isPermanentlyDenied) {
                return false;
              }
              return false;
            }
          }
        } else {
          Permission permissionToRequest;
          if (Platform.isAndroid) {
            int apiLevel = 33; // Default to Android 13+
            try {
              final androidInfo = await DeviceInfoPlugin().androidInfo;
              apiLevel = androidInfo.version.sdkInt;
            } catch (e) {
              // Fallback to assuming Android 13+
            }
            permissionToRequest = apiLevel >= 33 ? Permission.photos : Permission.storage;
          } else {
            permissionToRequest = Permission.photos;
          }

          var status = await permissionToRequest.status;
          if (!status.isGranted) {
            status = await permissionToRequest.request();
            if (!status.isGranted) {
              if (status.isPermanentlyDenied) {
                return false;
              }
              return false;
            }
          }
        }
        return true;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          return false;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return false;
  }

  static Future<File?> pickImage(ImageSource source) async {
    int retryCount = 0;
    const maxRetries = 2;
    while (retryCount < maxRetries) {
      bool hasPermission = await requestPermissions(source);
      if (!hasPermission) {
        retryCount++;
        if (retryCount >= maxRetries) {
          return null;
        }
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      try {
        final pickedFile = await _picker.pickImage(source: source);
        if (pickedFile == null) {
          return null;
        }

        final file = File(pickedFile.path);
        final ext = path.extension(pickedFile.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
          return null;
        }

        return file;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          return null;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  static Future<File?> compressImage(File imageFile, {int quality = 50}) async {
    try {
      final compressedPath = '${imageFile.path}_compressed.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        compressedPath,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return compressedFile != null ? File(compressedFile.path) : null;
    } catch (e) {
      return null;
    }
  }
}// 23497
// 19785
// 13416
// 30940
