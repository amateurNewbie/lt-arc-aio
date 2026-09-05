import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/user_repository.dart';

part 'user_provider.g.dart';

@riverpod
UserRepository userRepository(Ref ref) => UserRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<UserSummary>> userList(Ref ref) => ref.watch(userRepositoryProvider).list();
