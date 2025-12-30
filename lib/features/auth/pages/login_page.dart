import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/routes.dart';
import 'package:hiddify/features/auth/data/auth_failure.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        if (error is AuthFailure) {
          final t = ref.read(translationsProvider);
          errorMessage.value = error.present(t).type;
        } else {
          errorMessage.value = error.toString().contains('网络') || error.toString().contains('连接') ? '登录失败，请检查网络连接' : '登录失败: ${error.toString()}';
        }
        isLoading.value = false;
      } else if (next.hasValue && next.value!.isAuthenticated) {
        if (context.mounted) {
          const HomeRoute().go(context);
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    FluentIcons.shield_24_filled,
                    size: 64,
                  ),
                  const Gap(24),
                  Text(
                    '登录',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    '请输入您的邮箱和密码',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(32),
                  if (errorMessage.value != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            FluentIcons.error_circle_24_filled,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              errorMessage.value!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                  ],
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(FluentIcons.mail_24_regular),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入邮箱';
                      }
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(value)) {
                        return '请输入有效的邮箱地址';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) async {
                      if (formKey.currentState!.validate() && !isLoading.value) {
                        isLoading.value = true;
                        errorMessage.value = null;
                        try {
                          await authNotifier.login(
                            emailController.text.trim(),
                            passwordController.text,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            errorMessage.value = e.toString().replaceAll('AuthFailure.', '');
                            isLoading.value = false;
                          }
                        }
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                  const Gap(8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        const ForgotPasswordRoute().push(context);
                      },
                      child: const Text('忘记密码？'),
                    ),
                  ),
                  const Gap(24),
                  FilledButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              isLoading.value = true;
                              errorMessage.value = null;
                              try {
                                await authNotifier.login(
                                  emailController.text.trim(),
                                  passwordController.text,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  errorMessage.value = e.toString().replaceAll('AuthFailure.', '');
                                  isLoading.value = false;
                                }
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('登录'),
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('还没有账号？'),
                      TextButton(
                        onPressed: () {
                          const RegisterRoute().push(context);
                        },
                        child: const Text('立即注册'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
