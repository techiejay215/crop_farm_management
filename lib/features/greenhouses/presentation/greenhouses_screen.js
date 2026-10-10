import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../providers/greenhouse_provider.dart';

class GreenhousesScreen extends ConsumerWidget {
  const GreenhousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final ghAsync = ref.watch(greenhousesStreamProvider);

    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Greenhouses')),
        body: const Center(child: Text('Select a farm first from the Farms tab.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Greenhouses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/greenhouses/add'),
          ),
        ],
      ),
      body: ghAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No greenhouses yet. Tap + to add one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final gh = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryGreen,
                    child: const Icon(Icons.warehouse, color: Colors.white),
                  ),
                  title: Text(gh.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${gh.size} m² • ${gh.currentCrop}\n${gh.plantCount} plants'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/greenhouses/${gh.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}