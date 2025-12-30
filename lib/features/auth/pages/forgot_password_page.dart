import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/routes.dart';
import 'package:hiddify/features/auth/data/auth_failure.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ForgotPasswordPage extends HookConsumerWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final emailController = useTextEditingController();
    final verificationCodeController = useTextEditingController();
    final newPasswordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final step = useState(0);
    final countdown = useState<int?>(null);
    final canSendCode = useState(true);
    final countdownTimer = useRef<Timer?>(null);

    useEffect(() {
      return () {
        countdownTimer.value?.cancel();
      };
    }, []);

    void startCountdown() {
      countdown.value = 60;
      canSendCode.value = false;
      countdownTimer.value?.cancel();
      countdownTimer.value = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (countdown.value! > 0) {
          countdown.value = countdown.value! - 1;
        } else {
          countdown.value = null;
          canSendCode.value = true;
          timer.cancel();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                if (step.value == 0) ...[
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(FluentIcons.mail_24_regular),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
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
                  const Gap(24),
                  FilledButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              isLoading.value = true;
                              errorMessage.value = null;
                              try {
                                await authNotifier.forgotPassword(
                                  emailController.text.trim(),
                                );
                                step.value = 1;
                                startCountdown();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('验证码已发送到您的邮箱')),
                                  );
                                }
                              } catch (e) {
                                final error = e;
                                if (error is AuthFailure) {
                                  final t = ref.read(translationsProvider);
                                  errorMessage.value = error.present(t).type;
                                } else {
                                  errorMessage.value = '操作失败，请检查网络连接';
                                }
                              } finally {
                                isLoading.value = false;
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
                        : const Text('发送验证码'),
                  ),
                ] else ...[
                  Text(
                    '验证码已发送至: ${emailController.text}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: verificationCodeController,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            prefixIcon: Icon(FluentIcons.key_24_regular),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入验证码';
                            }
                            if (value.length != 6) {
                              return '验证码为6位数字';
                            }
                            return null;
                          },
                        ),
                      ),
                      const Gap(8),
                      OutlinedButton(
                        onPressed: canSendCode.value
                            ? () async {
                                try {
                                  await authNotifier.forgotPassword(
                                    emailController.text.trim(),
                                  );
                                  startCountdown();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('验证码已重新发送')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('发送失败，请稍后重试')),
                                    );
                                  }
                                }
                              }
                            : null,
                        child: Text(countdown.value != null ? '${countdown.value}秒' : '重新发送'),
                      ),
                    ],
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: newPasswordController,
                    decoration: const InputDecoration(
                      labelText: '新密码',
                      prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
                      border: OutlineInputBorder(),
                      helperText: '密码长度至少8位',
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入新密码';
                      }
                      if (value.length < 8) {
                        return '密码长度至少8位';
                      }
                      if (value.length > 128) {
                        return '密码长度不能超过128位';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: '确认密码',
                      prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请确认密码';
                      }
                      if (value != newPasswordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
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
                                await authNotifier.resetPassword(
                                  emailController.text.trim(),
                                  verificationCodeController.text.trim(),
                                  newPasswordController.text,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('密码重置成功')),
                                  );
                                  const LoginRoute().go(context);
                                }
                              } catch (e) {
                                final error = e;
                                if (error is AuthFailure) {
                                  final t = ref.read(translationsProvider);
                                  errorMessage.value = error.present(t).type;
                                } else {
                                  errorMessage.value = '操作失败，请检查网络连接';
                                }
                              } finally {
                                isLoading.value = false;
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
                        : const Text('重置密码'),
                  ),
                ],
                const Gap(16),
                TextButton(
                  onPressed: () {
                    const LoginRoute().go(context);
                  },
                  child: const Text('返回登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

