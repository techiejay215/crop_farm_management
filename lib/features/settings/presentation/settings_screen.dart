import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/image_upload_field.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  XFile? _pickedPhoto;
  bool _loading = false;
  bool _uploadingPhoto = false;

  Future<void> _pickPhoto() async {
    final file = await pickImageWithSource(context);
    if (file != null) {
      setState(() => _pickedPhoto = file);
      await _uploadPhoto();
    }
  }

  Future<void> _uploadPhoto() async {
    if (_pickedPhoto == null) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await StorageService().uploadUserPhoto(
        uid: user.uid,
        file: _pickedPhoto!,
      );
      await ref.read(authRepositoryProvider).updateUserProfile(
        uid: user.uid,
        data: {'photoUrl': url},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
      setState(() => _pickedPhoto = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: userDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No profile data.'));
          }
          final name = data['name'] ?? 'User';
          final email = data['email'] ?? '';
          final role = (data['role'] ?? 'customer').toString();
          final photoUrl = data['photoUrl'] as String?;
          final phone = data['phone'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      ImageUploadField(
                        imageUrl: photoUrl,
                        label: _uploadingPhoto
                            ? 'Uploading...'
                            : 'Tap to change picture',
                        fallbackIcon: Icons.person,
                        onTap: _uploadingPhoto ? () {} : _pickPhoto,
                      ),
                      if (_uploadingPhoto)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _infoTile(Icons.person, 'Name', name),
                _infoTile(Icons.email, 'Email', email),
                if (phone.isNotEmpty) _infoTile(Icons.phone, 'Phone', phone),
                _infoTile(Icons.badge, 'Role', role.toUpperCase()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryGreen),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}