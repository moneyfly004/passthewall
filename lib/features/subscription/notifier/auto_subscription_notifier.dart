import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/subscription/data/subscription_api.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'auto_subscription_notifier.g.dart';

@Riverpod(keepAlive: true)
SubscriptionApi subscriptionApi(SubscriptionApiRef ref) {
  const baseUrl = 'https://dy.moneyfly.top';
  return SubscriptionApi(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: baseUrl,
  );
}

@Riverpod(keepAlive: true)
class AutoSubscriptionNotifier extends _$AutoSubscriptionNotifier with AppLogger {
  @override
  Future<void> build() async {
    ref.listen<AsyncValue<AuthState>>(
      authNotifierProvider,
      (previous, next) {
        final previousAuth = previous?.valueOrNull?.isAuthenticated ?? false;
        final nextAuth = next.valueOrNull?.isAuthenticated ?? false;
        if (!previousAuth && nextAuth) {
          _fetchAndUpdateSubscription();
        }
      },
    );

    final authState = ref.read(authNotifierProvider);
    final isAuthenticated = authState.valueOrNull?.isAuthenticated ?? false;
    if (isAuthenticated) {
      await _fetchAndUpdateSubscription();
    }
  }

  Future<void> _fetchAndUpdateSubscription() async {
    try {
      loggy.info("🔄 开始获取用户订阅信息...");
      final subscriptionApi = ref.read(subscriptionApiProvider);
      final subscription = await subscriptionApi.getUserSubscription();

      if (subscription != null && subscription.isNotEmpty) {
        loggy.info("✅ 获取到订阅信息: ${subscription.keys}");
        String? universalUrl = subscription['universal_url'] as String?;

        if (universalUrl == null || universalUrl.isEmpty) {
          final subscriptionUrl = subscription['subscription_url'] as String?;
          if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
            universalUrl = subscriptionApi.getUniversalSubscriptionUrl(subscriptionUrl);
          }
        }

        if (universalUrl != null && universalUrl.isNotEmpty) {
          String profileName = "订阅";
          final expireTimeStr = subscription['expire_time'] as String?;
          if (expireTimeStr != null && expireTimeStr.isNotEmpty && expireTimeStr != "未设置") {
            try {
              final expireTime = DateTime.parse(expireTimeStr);
              final year = expireTime.year;
              final month = expireTime.month.toString().padLeft(2, '0');
              final day = expireTime.day.toString().padLeft(2, '0');
              profileName = "到期: $year-$month-$day";
            } catch (e) {
              profileName = "到期: $expireTimeStr";
            }
          }

          final profileId = const Uuid().v4();
          final baseProfile = RemoteProfileEntity(
            id: profileId,
            active: true,
            name: profileName,
            url: universalUrl,
            lastUpdate: DateTime.now(),
            options: ProfileOptions(
              updateInterval: const Duration(hours: 1),
            ),
          );

          loggy.info("📝 正在添加订阅到profile: name=$profileName, url=$universalUrl");
          final profileRepo = ref.read(profileRepositoryProvider).requireValue;
          final result = await profileRepo.add(baseProfile).run();
          result.fold(
            (failure) {
              loggy.error("❌ 自动获取订阅失败: $failure");
            },
            (_) {
              loggy.info("✅ 订阅已生效！已添加到profile并设置为active，名称: $profileName");
            },
          );
        } else {
          loggy.warning("⚠️ 订阅数据中没有有效的订阅URL");
        }
      } else {
        loggy.warning("⚠️ 获取订阅返回null或空数据，可能是用户没有订阅或API调用失败");
      }
    } catch (e, stackTrace) {
      loggy.error("❌ 自动获取订阅异常", e, stackTrace);
    }
  }

  Future<void> refreshSubscription() async {
    await _fetchAndUpdateSubscription();
  }
}
