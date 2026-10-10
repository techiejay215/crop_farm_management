import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StorageService {
  // ---- Cloudinary credentials ----
  static const String _cloudName = 'dove5yk6u';
  static const String _uploadPreset = 'greenharvest_unsigned';

  /// Uploads a farm logo to Cloudinary and returns the secure URL.
  Future<String> uploadFarmLogo({
    required String farmId,
    required XFile file,
  }) async {
    return _uploadToCloudinary(file, folder: 'farms/$farmId');
  }

  /// Uploads a user profile picture to Cloudinary and returns the secure URL.
  Future<String> uploadUserPhoto({
    required String uid,
    required XFile file,
  }) async {
    return _uploadToCloudinary(file, folder: 'users/$uid');
  }

  /// Internal helper to handle the multipart HTTP request to Cloudinary.
  Future<String> _uploadToCloudinary(XFile file, {String? folder}) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    // Required params
    request.fields['upload_preset'] = _uploadPreset;
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }

    // Read bytes (works on web + mobile + desktop)
    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ),
    );

    // Send
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      String errorMessage = 'Upload failed';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['error']?['message'] ?? errorMessage;
      } catch (_) {
        // Ignore JSON parse errors — fall back to default message
      }
      throw Exception('Cloudinary upload failed: $errorMessage');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;

    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary did not return a secure URL.');
    }

    return secureUrl;
  }

  /// Placeholder for deletion — see class docstring for why.
  Future<void> deleteFile(String publicId) async {
    return;
  }
}