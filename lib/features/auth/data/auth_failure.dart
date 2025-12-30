import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';

part 'auth_failure.freezed.dart';

@freezed
class AuthFailure with _$AuthFailure implements Failure {
  const factory AuthFailure.unknown(String message) = _Unknown;
  const factory AuthFailure.network(String? message) = _Network;
  const factory AuthFailure.invalidCredentials() = _InvalidCredentials;
  const factory AuthFailure.userNotFound() = _UserNotFound;
  const factory AuthFailure.emailAlreadyExists() = _EmailAlreadyExists;
  const factory AuthFailure.verificationCodeExpired() =
      _VerificationCodeExpired;
  const factory AuthFailure.verificationCodeInvalid() =
      _VerificationCodeInvalid;

  const AuthFailure._();

  @override
  ({String type, String? message}) present(TranslationsEn t) => when(
        unknown: (message) => (type: message, message: null),
        network: (message) => (
            type: t.failure.connection.connectionError,
            message: message),
        invalidCredentials: () => (
            type: '用户名或密码错误',
            message: null),
        userNotFound: () => (type: '用户不存在', message: null),
        emailAlreadyExists: () => (type: '邮箱已被注册', message: null),
        verificationCodeExpired: () => (type: '验证码已过期', message: null),
        verificationCodeInvalid: () => (type: '验证码无效', message: null),
      );
}


