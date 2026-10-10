import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';

class ImageUploadField extends StatelessWidget {
  final String? imageUrl;            // existing URL (or null if new)
  final String label;                // "Farm Logo" or "Profile Picture"
  final IconData fallbackIcon;       // shown if no image
  final Color fallbackColor;
  final double size;
  final VoidCallback onTap;

  const ImageUploadField({
    super.key,
    this.imageUrl,
    required this.label,
    required this.fallbackIcon,
    this.fallbackColor = AppTheme.primaryGreen,
    this.size = 120,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fallbackColor.withValues(alpha: 0.1),
                  border: Border.all(color: fallbackColor, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          fallbackIcon,
                          size: size * 0.4,
                          color: fallbackColor,
                        ),
                      )
                    : Icon(
                        fallbackIcon,
                        size: size * 0.4,
                        color: fallbackColor,
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Helper: shows a bottom sheet to pick Camera or Gallery
Future<XFile?> pickImageWithSource(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppTheme.primaryGreen),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final picker = ImagePicker();
  return picker.pickImage(
    source: source,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
}