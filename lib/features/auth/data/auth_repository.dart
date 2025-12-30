import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/features/auth/data/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_models.dart';

class AuthRepository {
  final DioHttpClient _httpClient;
  final String baseUrl;

  AuthRepository({
    required DioHttpClient httpClient,
    required this.baseUrl,
  }) : _httpClient = httpClient;

  Future<Either<AuthFailure, AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$baseUrl/api/v1/auth/login',
        data: request.toJson(),
        proxyOnly: false,
      );
      final data = response.data;
      if (data != null) {
        if (data['success'] == true || data['success'] == 'true') {
          final responseData = data['data'];
          if (responseData != null && responseData is Map<String, dynamic>) {
            final authData = <String, dynamic>{
              'success': true,
              'token': responseData['access_token'],
              'user': responseData['user'],
            };
            return right(AuthResponse.fromJson(authData));
          } else {
            return right(AuthResponse.fromJson(data));
          }
        } else {
          final message = (data['message'] as String?) ?? '登录失败';
          if (message.contains('密码') || message.contains('用户名') || message.contains('邮箱') || message.contains('错误')) {
            return left(const AuthFailure.invalidCredentials());
          }
          return left(AuthFailure.unknown(message));
        }
      } else {
        return left(AuthFailure.unknown('服务器返回空数据'));
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          final data = e.response!.data;
          if (data is Map<String, dynamic>) {
            final message = (data['message'] as String?) ?? '请求失败';
            return left(AuthFailure.unknown(message));
          }
        }
      }
      return left(AuthFailure.network(e.message ?? '网络连接失败'));
    } catch (e) {
      return left(AuthFailure.network('网络请求失败: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, AuthResponse>> register(
    RegisterRequest request,
  ) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$baseUrl/api/v1/auth/register',
        data: request.toJson(),
        proxyOnly: false,
      );
      final data = response.data;
      if (data != null) {
        if (data['success'] == true || data['success'] == 'true') {
          final responseData = data['data'];
          if (responseData != null && responseData is Map<String, dynamic>) {
            final authData = <String, dynamic>{
              'success': true,
              'token': responseData['access_token'],
              'user': responseData['user'],
            };
            return right(AuthResponse.fromJson(authData));
          } else {
            return right(AuthResponse.fromJson(data));
          }
        } else {
          final message = (data['message'] as String?) ?? '注册失败';
          if (message.contains('邮箱') && message.contains('已')) {
            return left(const AuthFailure.emailAlreadyExists());
          }
          return left(AuthFailure.unknown(message));
        }
      } else {
        return left(AuthFailure.unknown('服务器返回空数据'));
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          final data = e.response!.data;
          if (data is Map<String, dynamic>) {
            final message = (data['message'] as String?) ?? '请求失败';
            return left(AuthFailure.unknown(message));
          }
        }
      }
      return left(AuthFailure.network(e.message ?? '网络连接失败'));
    } catch (e) {
      return left(AuthFailure.network('网络请求失败: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, void>> sendVerificationCode(
    SendVerificationCodeRequest request,
  ) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$baseUrl/api/v1/auth/verification/send',
        data: request.toJson(),
        proxyOnly: false,
      );
      final data = response.data;
      if (data != null && (data['success'] == true || data['success'] == 'true')) {
        return right(unit);
      } else {
        return left(
          AuthFailure.unknown(
            (data?['message'] as String?) ?? '发送验证码失败',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          final data = e.response!.data;
          if (data is Map<String, dynamic>) {
            final message = (data['message'] as String?) ?? '请求失败';
            return left(AuthFailure.unknown(message));
          }
        }
      }
      return left(AuthFailure.network(e.message ?? '网络连接失败'));
    } catch (e) {
      return left(AuthFailure.network('网络请求失败: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, void>> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$baseUrl/api/v1/auth/forgot-password',
        data: request.toJson(),
        proxyOnly: false,
      );
      final data = response.data;
      if (data != null && (data['success'] == true || data['success'] == 'true')) {
        return right(unit);
      } else {
        final message = (data?['message'] as String?) ?? '发送重置密码邮件失败';
        if (message.contains('不存在')) {
          return left(const AuthFailure.userNotFound());
        }
        return left(AuthFailure.unknown(message));
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          final data = e.response!.data;
          if (data is Map<String, dynamic>) {
            final message = (data['message'] as String?) ?? '请求失败';
            return left(AuthFailure.unknown(message));
          }
        }
      }
      return left(AuthFailure.network(e.message ?? '网络连接失败'));
    } catch (e) {
      return left(AuthFailure.network('网络请求失败: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, void>> resetPassword(
    ResetPasswordRequest request,
  ) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$baseUrl/api/v1/auth/reset-password',
        data: request.toJson(),
        proxyOnly: false,
      );
      final data = response.data;
      if (data != null && (data['success'] == true || data['success'] == 'true')) {
        return right(unit);
      } else {
        final message = (data?['message'] as String?) ?? '重置密码失败';
        if (message.contains('过期')) {
          return left(const AuthFailure.verificationCodeExpired());
        }
        if (message.contains('无效') || message.contains('错误')) {
          return left(const AuthFailure.verificationCodeInvalid());
        }
        return left(AuthFailure.unknown(message));
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          final data = e.response!.data;
          if (data is Map<String, dynamic>) {
            final message = (data['message'] as String?) ?? '请求失败';
            return left(AuthFailure.unknown(message));
          }
        }
      }
      return left(AuthFailure.network(e.message ?? '网络连接失败'));
    } catch (e) {
      return left(AuthFailure.network('网络请求失败: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserSubscription>> getUserSubscription(
    String token,
  ) async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '$baseUrl/api/v1/subscriptions/user-subscription',
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      final data = response.data;
      if (data != null && (data['success'] == true || data['success'] == 'true') && data['data'] != null) {
        return right(UserSubscription.fromJson(data['data'] as Map<String, dynamic>));
      } else {
        return left(
          AuthFailure.unknown(
            (data?['message'] as String?) ?? '获取订阅信息失败',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          final data = e.response!.data;
          if (data is Map<String, dynamic>) {
            final message = (data['message'] as String?) ?? '请求失败';
            return left(AuthFailure.unknown(message));
          }
        }
      }
      return left(AuthFailure.network(e.message ?? '网络连接失败'));
    } catch (e) {
      return left(AuthFailure.network('网络请求失败: ${e.toString()}'));
    }
  }
}
