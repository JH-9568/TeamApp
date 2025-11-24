import 'package:frontend/common/models/user.dart';

import 'mypage_api.dart';

class MyPageRepository {
  const MyPageRepository(this._api);

  final MyPageApi _api;

  Future<User> fetchProfile() => _api.fetchProfile();

  Future<User> updateProfile({String? name, String? avatar}) {
    return _api.updateProfile(name: name, avatar: avatar);
  }
}
