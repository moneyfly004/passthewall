import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/auth/data/auth_failure.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'subscription_sync_notifier.g.dart';

@riverpod
class SubscriptionSyncNotifier extends _$SubscriptionSyncNotifier with AppLogger {
  @override
  Future<void> build() async {
    Future.delayed(const Duration(seconds: 3), () {
      syncSubscription();
    });
  }

  Future<void> syncSubscription() async {
    try {
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.valueOrNull?.isAuthenticated ?? false;
      if (!isAuthenticated) {
        loggy.debug('User not authenticated, skipping subscription sync');
        return;
      }

      final token = authState.valueOrNull?.token;
      if (token == null) {
        loggy.debug('No auth token, skipping subscription sync');
        return;
      }

      final repository = ref.read(authRepositoryProvider);
      final subscriptionResult = await repository.getUserSubscription(token).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          loggy.warning('Get subscription timeout');
          return left(AuthFailure.network('获取订阅超时'));
        },
      );

      await subscriptionResult.fold(
        (failure) async {
          loggy.warning('Failed to get subscription: $failure');
        },
        (subscription) async {
          try {
            final subscriptionUrl = subscription.universalUrl;
            String profileName = "订阅";
            final expireTimeStr = subscription.expireTime;
            if (expireTimeStr.isNotEmpty && expireTimeStr != "未设置") {
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

            final prefs = await SharedPreferences.getInstance();
            final savedUrl = prefs.getString('subscription_url');

            await prefs.setString('subscription_url', subscriptionUrl);
            await prefs.setString('subscription_name', profileName);
            await prefs.setString('subscription_expire_time', expireTimeStr);

            await Future.delayed(const Duration(seconds: 2));

            try {
              final addProfile = ref.read(addProfileProvider.notifier);
              await addProfile.add(subscriptionUrl).timeout(
                const Duration(seconds: 60),
                onTimeout: () {
                  loggy.warning('Subscription add timeout');
                },
              );
              loggy.info('Subscription profile ${savedUrl == subscriptionUrl ? "updated" : "added"}: $profileName');
            } catch (e, stackTrace) {
              loggy.warning('Error ${savedUrl == subscriptionUrl ? "updating" : "adding"} subscription profile', e, stackTrace);
            }

            loggy.info('Subscription synced: $profileName');
          } catch (e, stackTrace) {
            loggy.warning('Error processing subscription', e, stackTrace);
          }
        },
      );
    } catch (e, stackTrace) {
      loggy.warning('Error syncing subscription', e, stackTrace);
    }
  }
}
