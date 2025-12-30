import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/animated_visibility.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/gen/fonts.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

String? _extractCountryCode(String name) {
  final countryCodePattern = RegExp(r'\b([A-Z]{2})\b');
  final match = countryCodePattern.firstMatch(name.toUpperCase());
  if (match != null) {
    final code = match.group(1);
    const validCodes = {'US', 'CN', 'JP', 'HK', 'SG', 'TW', 'KR', 'GB', 'DE', 'FR', 'CA', 'AU', 'NL', 'IN', 'RU', 'TH', 'MY', 'VN', 'PH', 'ID', 'BR', 'MX', 'ES', 'IT', 'CH', 'SE', 'NO', 'DK', 'FI', 'PL', 'TR', 'GR', 'PT', 'IE', 'NZ', 'ZA'};
    if (validCodes.contains(code)) {
      return code;
    }
  }

  final cityToCountry = {
    'tokyo': 'JP',
    'osaka': 'JP',
    'seoul': 'KR',
    'london': 'GB',
    'frankfurt': 'DE',
    'paris': 'FR',
    'toronto': 'CA',
    'sydney': 'AU',
    'mumbai': 'IN',
    'moscow': 'RU',
    'amsterdam': 'NL',
    'taipei': 'TW',
    'bangkok': 'TH',
    'hanoi': 'VN',
    'singapore': 'SG',
    'hongkong': 'HK',
    'hong kong': 'HK',
    'shanghai': 'CN',
    'beijing': 'CN',
    'guangzhou': 'CN',
    'shenzhen': 'CN',
    'new york': 'US',
    'los angeles': 'US',
    'chicago': 'US',
    'miami': 'US',
    'san francisco': 'US',
    'dallas': 'US',
    'seattle': 'US',
  };

  final lowerName = name.toLowerCase();
  for (final entry in cityToCountry.entries) {
    if (lowerName.contains(entry.key)) {
      return entry.value;
    }
  }

  return null;
}

class ProxySelectionList extends HookConsumerWidget {
  const ProxySelectionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final asyncProxies = ref.watch(proxiesOverviewNotifierProvider);
    final notifier = ref.watch(proxiesOverviewNotifierProvider.notifier);

    final isConnected = connectionStatus.valueOrNull?.isConnected ?? false;
    if (!isConnected) {
      return const SizedBox();
    }

    return AnimatedVisibility(
      axis: Axis.vertical,
      visible: isConnected,
      child: switch (asyncProxies) {
        AsyncData(value: final groups) when groups.isNotEmpty => _buildProxyList(context, ref, groups.first, notifier, t),
        AsyncData(value: final groups) when groups.isEmpty => _buildEmptyState(context, ref, t),
        AsyncLoading() => _buildLoadingState(context, t),
        AsyncError() => _buildErrorState(context, ref, t),
        _ => const SizedBox(),
      },
    );
  }

  Widget _buildLoadingState(BuildContext context, TranslationsEn t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const Gap(12),
          Text(
            '正在加载节点列表...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, TranslationsEn t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.error_circle_20_regular,
                color: Theme.of(context).colorScheme.error,
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  '无法加载节点列表',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const Gap(8),
          TextButton(
            onPressed: () {
              ref.invalidate(proxiesOverviewNotifierProvider);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, TranslationsEn t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.info_20_regular),
              const Gap(12),
              Expanded(
                child: Text(
                  '暂无可用节点',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const Gap(8),
          TextButton(
            onPressed: () {
              ref.invalidate(proxiesOverviewNotifierProvider);
            },
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }

  Widget _buildProxyList(
    BuildContext context,
    WidgetRef ref,
    ProxyGroupEntity group,
    ProxiesOverviewNotifier notifier,
    TranslationsEn t,
  ) {
    final filteredItems = group.items.where((item) => item.type != 'Direct').toList();
    final displayItems = filteredItems.take(20).toList();

    if (displayItems.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(FluentIcons.arrow_routing_20_regular, size: 18),
                const Gap(8),
                Text(
                  t.proxies.pageTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (displayItems.length < filteredItems.length)
                  Text(
                    '${displayItems.length}/${filteredItems.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: displayItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final proxy = displayItems[index];
                final isSelected = group.selected == proxy.tag;
                final countryCode = _extractCountryCode(proxy.name);

                return InkWell(
                  onTap: () async {
                    if (isSelected) return;
                    await notifier.changeProxy(group.tag, proxy.tag);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          ),
                        ),
                        const Gap(12),
                        if (countryCode != null)
                          IPCountryFlag(
                            countryCode: countryCode,
                            size: 20,
                          )
                        else
                          const Icon(
                            FluentIcons.globe_20_regular,
                            size: 20,
                            color: Colors.grey,
                          ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                proxy.name,
                                style: TextStyle(
                                  fontFamily: FontFamily.emoji,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (proxy.urlTestDelay > 0 && proxy.urlTestDelay <= 65000)
                                Text(
                                  '${proxy.urlTestDelay} ms',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: _delayColor(context, proxy.urlTestDelay),
                                        fontSize: 12,
                                      ),
                                )
                              else if (proxy.urlTestDelay > 65000)
                                Text(
                                  t.general.timeout,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.error,
                                        fontSize: 12,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            FluentIcons.checkmark_circle_20_filled,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _delayColor(BuildContext context, int delay) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return switch (delay) {
        < 800 => Colors.lightGreen,
        < 1500 => Colors.orange,
        _ => Colors.redAccent,
      };
    }
    return switch (delay) {
      < 800 => Colors.green,
      < 1500 => Colors.deepOrangeAccent,
      _ => Colors.red,
    };
  }
}

