import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/utils/utils.dart';

class SubscriptionApi with AppLogger {
  SubscriptionApi({
    required this.httpClient,
    required this.baseUrl,
  });

  final DioHttpClient httpClient;
  final String baseUrl;

  String get _apiBase => '$baseUrl/api/v1';

  Future<Map<String, dynamic>?> getUserSubscription() async {
    try {
      loggy.info("📡 请求用户订阅信息...");
      final response = await httpClient.get<Map<String, dynamic>>(
        '$_apiBase/subscriptions/user-subscription',
        proxyOnly: false,
      );

      loggy.debug("订阅信息响应: statusCode=${response.statusCode}");

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data!;
        final data = responseData['data'] as Map<String, dynamic>? ?? responseData as Map<String, dynamic>?;

        if (data != null) {
          final expireTime = data['expire_time'] as String?;
          loggy.info("✅ 获取订阅信息成功: expireTime=$expireTime");
        } else {
          loggy.warning("⚠️ 订阅信息数据为空");
        }

        return data;
      } else {
        loggy.warning("⚠️ 获取订阅信息失败: statusCode=${response.statusCode}");
      }
      return null;
    } catch (e, stackTrace) {
      loggy.error("❌ 获取用户订阅异常", e, stackTrace);
      return null;
    }
  }

  String getUniversalSubscriptionUrl(String subscriptionUrl) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (subscriptionUrl.startsWith('http://') || subscriptionUrl.startsWith('https://')) {
      return '$subscriptionUrl?t=$timestamp';
    }
    return '$_apiBase/subscriptions/universal/$subscriptionUrl?t=$timestamp';
  }

  String getClashSubscriptionUrl(String subscriptionUrl) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '$_apiBase/subscriptions/clash/$subscriptionUrl?t=$timestamp';
  }
}

