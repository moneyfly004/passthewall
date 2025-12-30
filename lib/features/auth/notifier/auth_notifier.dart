import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/data/auth_repository.dart';
import 'package:hiddify/features/auth/model/auth_models.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_notifier.freezed.dart';
part 'auth_notifier.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  const baseUrl = 'https://dy.moneyfly.top';
  return AuthRepository(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: baseUrl,
  );
}

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier with AppLogger {
  @override
  Future<AuthState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');

    if (token != null && userJson != null) {
      try {
        ref.read(httpClientProvider).setAccessToken(token);
        return AuthState.authenticated(
          token: token,
          user: userJson,
        );
      } catch (e) {
        loggy.warning('Failed to parse user data', e);
        return const AuthState.unauthenticated();
      }
    }
    return const AuthState.unauthenticated();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final result = await repository.login(
        LoginRequest(email: email, password: password),
      );

      return result.fold(
        (failure) => throw failure,
        (response) async {
          if (response.token != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', response.token!);
            if (response.user != null) {
              await prefs.setString(
                'auth_user',
                response.user.toString(),
              );
            }

            ref.read(httpClientProvider).setAccessToken(response.token!);

            return AuthState.authenticated(
              token: response.token!,
              user: response.user?.toString() ?? '',
            );
          } else {
            throw Exception(response.message ?? '登录失败');
          }
        },
      );
    });
  }

  Future<void> register(
    String username,
    String email,
    String password,
    String? verificationCode,
    String? inviteCode,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final result = await repository.register(
        RegisterRequest(
          username: username,
          email: email,
          password: password,
          verificationCode: verificationCode,
          inviteCode: inviteCode,
        ),
      );

      return result.fold(
        (failure) => throw failure,
        (response) async {
          if (response.token != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', response.token!);
            if (response.user != null) {
              await prefs.setString(
                'auth_user',
                response.user.toString(),
              );
            }

            ref.read(httpClientProvider).setAccessToken(response.token!);

            return AuthState.authenticated(
              token: response.token!,
              user: response.user?.toString() ?? '',
            );
          } else {
            throw Exception(response.message ?? '注册失败');
          }
        },
      );
    });
  }

  Future<void> sendVerificationCode(String email, String purpose) async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.sendVerificationCode(
      SendVerificationCodeRequest(email: email, type: 'email'),
    );
    result.fold(
      (failure) => throw failure,
      (_) => null,
    );
  }

  Future<void> forgotPassword(String email) async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.forgotPassword(
      ForgotPasswordRequest(email: email),
    );
    result.fold(
      (failure) => throw failure,
      (_) => null,
    );
  }

  Future<void> resetPassword(
    String email,
    String verificationCode,
    String newPassword,
  ) async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.resetPassword(
      ResetPasswordRequest(
        email: email,
        verificationCode: verificationCode,
        newPassword: newPassword,
      ),
    );
    result.fold(
      (failure) => throw failure,
      (_) => null,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    ref.read(httpClientProvider).clearAccessToken();
    state = const AsyncData(AuthState.unauthenticated());
  }

  bool get isAuthenticated {
    return state.valueOrNull?.isAuthenticated ?? false;
  }

  String? get token {
    return state.valueOrNull?.token;
  }
}

@freezed
class AuthState with _$AuthState {
  const AuthState._();

  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.authenticated({
    required String token,
    required String user,
  }) = _Authenticated;

  bool get isAuthenticated {
    return this is _Authenticated;
  }

  String? get token {
    return mapOrNull(
      authenticated: (state) => state.token,
    );
  }
}
