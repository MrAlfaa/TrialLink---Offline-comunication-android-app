import 'user_model.dart';

class AuthResponseModel {
  const AuthResponseModel({
    required this.user,
    required this.token,
  });

  final UserModel user;
  final String token;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'].toString(),
    );
  }
}
