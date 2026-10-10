import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/crop_activity_model.dart';
import '../data/crop_activity_repository.dart';

final cropActivityRepositoryProvider =
    Provider<CropActivityRepository>((ref) => CropActivityRepository());

/// Streams all activities for a crop. Pass (farmId, cropId).
final cropActivitiesStreamProvider =
    StreamProvider.family<List<CropActivity>, ({String farmId, String cropId})>(
  (ref, args) {
    return ref
        .watch(cropActivityRepositoryProvider)
        .streamActivities(farmId: args.farmId, cropId: args.cropId);
  },
);

/// Selected activity type filter (null = show all).
final activityTypeFilterProvider = StateProvider<String?>((ref) => null);