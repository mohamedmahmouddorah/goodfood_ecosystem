
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';

import '../services/chef_remote_service.dart';

abstract class ChefRepository {
  Stream<List<UserModel>> getChefsStream();
  Future<void> addChef(UserModel chef, {required String password});
  Future<void> updateChef(UserModel chef);
  Future<void> toggleStatus(String uid, AccountStatus newStatus);
  Future<void> deleteChef(String uid);
}

class ChefRepositoryImpl implements ChefRepository {
  final ChefRemoteService _remoteService;

  ChefRepositoryImpl({ChefRemoteService? remoteService})
      : _remoteService = remoteService ?? ChefRemoteService.instance;

  @override
  Stream<List<UserModel>> getChefsStream() => _remoteService.getChefsStream();

  @override
  Future<void> addChef(UserModel chef, {required String password}) =>
      _remoteService.addChef(chef, password: password);

  @override
  Future<void> updateChef(UserModel chef) => _remoteService.updateChef(chef);

  @override
  Future<void> toggleStatus(String uid, AccountStatus newStatus) =>
      _remoteService.toggleStatus(uid, newStatus);

  @override
  Future<void> deleteChef(String uid) => _remoteService.deleteChef(uid);
}
