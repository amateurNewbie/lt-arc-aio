import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/activity_repository.dart';

part 'activity_provider.g.dart';

@riverpod
ActivityRepository activityRepository(Ref ref) => ActivityRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Activity>> recentActivities(Ref ref) => ref.watch(activityRepositoryProvider).listRecent();
