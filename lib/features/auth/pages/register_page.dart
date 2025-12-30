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

class RegisterPage extends HookConsumerWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final usernameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final verificationCodeController = useTextEditingController();
    final inviteCodeController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final countdown = useState<int?>(null);
    final canSendCode = useState(true);
    final countdownTimer = useRef<Timer?>(null);
    final isValidEmail = useState(false);

    useEffect(() {
      void listener() {
        final email = emailController.text.trim();
        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
        isValidEmail.value = emailRegex.hasMatch(email);
      }

      emailController.addListener(listener);
      listener();
      return () => emailController.removeListener(listener);
    }, [emailController]);

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        if (error is AuthFailure) {
          final t = ref.read(translationsProvider);
          errorMessage.value = error.present(t).type;
        } else {
          errorMessage.value = '注册失败，请检查网络连接';
        }
        isLoading.value = false;
      } else if (next.hasValue && next.value!.isAuthenticated) {
        const HomeRoute().go(context);
      }
    });

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
        title: const Text('注册'),
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
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(FluentIcons.person_24_regular),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    if (value.length < 3) {
                      return '用户名至少3个字符';
                    }
                    if (value.length > 20) {
                      return '用户名不能超过20个字符';
                    }
                    return null;
                  },
                ),
                const Gap(16),
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
                      onPressed: canSendCode.value && isValidEmail.value && !isLoading.value
                          ? () async {
                              final email = emailController.text.trim();
                              try {
                                await authNotifier.sendVerificationCode(email, 'register');
                                startCountdown();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('验证码已发送')),
                                  );
                                }
                              } catch (e) {
                                canSendCode.value = true;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('发送失败: ${e.toString().replaceAll('AuthFailure.', '')}'),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      child: Text(countdown.value != null ? '${countdown.value}秒' : '发送验证码'),
                    ),
                  ],
                ),
                const Gap(16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(FluentIcons.lock_closed_24_regular),
                    border: OutlineInputBorder(),
                    helperText: '密码长度至少8位',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
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
                  controller: inviteCodeController,
                  decoration: InputDecoration(
                    labelText: '邀请码（可选）',
                    prefixIcon: Icon(FluentIcons.gift_24_regular),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
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
                              await authNotifier.register(
                                usernameController.text.trim(),
                                emailController.text.trim(),
                                passwordController.text,
                                verificationCodeController.text.trim(),
                                inviteCodeController.text.trim().isEmpty ? null : inviteCodeController.text.trim(),
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
                      : const Text('注册'),
                ),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('已有账号？'),
                    TextButton(
                      onPressed: () {
                        const LoginRoute().push(context);
                      },
                      child: const Text('立即登录'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
