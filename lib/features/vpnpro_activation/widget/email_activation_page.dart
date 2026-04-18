import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/branding/branding.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/vpnpro_activation/model/activation_failure.dart';
import 'package:hiddify/features/vpnpro_activation/notifier/activation_notifier.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// First-launch email-activation screen (Phase 5).
///
/// Replaces the stock Hiddify intro when [Branding.enableEmailActivation]
/// is `true`. On success the activation chain runs to completion
/// ([ActivationNotifier.activate]) and the router redirects to /home.
///
/// Escape hatch: "Пропустить" → /intro (stock Hiddify onboarding, where
/// the user can paste a subscription URL manually or complete onboarding
/// without a subscription).
///
/// RU-only by product decision — all strings are hardcoded Russian. If a
/// future release needs localisation, move them into the arb files.
class EmailActivationPage extends HookConsumerWidget with PresLogger {
  const EmailActivationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(activationNotifierProvider);
    final notifier = ref.read(activationNotifierProvider.notifier);

    final emailController = useTextEditingController();
    final emailFocusNode = useFocusNode();
    final formKey = useMemoized(GlobalKey<FormState>.new, const []);
    final hasInput = useState(false);

    useEffect(() {
      void listener() {
        final next = emailController.text.trim().isNotEmpty;
        if (next != hasInput.value) hasInput.value = next;
      }

      emailController.addListener(listener);
      return () => emailController.removeListener(listener);
    }, const []);

    // Resolve errors into an inline error string to show under the field.
    String? errorText;
    if (state is AsyncError) {
      final err = state.error;
      if (err is ActivationFailure) {
        // ActivationFailure.present() ignores the TranslationsEn argument
        // (RU strings are hardcoded), but the interface requires one. Pull
        // the real translations via the provider — safe: translations are
        // initialised before any page renders.
        final t = ref.read(translationsProvider).requireValue;
        final pair = err.present(t);
        errorText = pair.message ?? pair.type;
      } else {
        errorText = err.toString();
      }
    }

    Future<void> submit() async {
      if (state.isLoading) return;
      if (!(formKey.currentState?.validate() ?? false)) return;
      FocusScope.of(context).unfocus();
      await notifier.activate(emailController.text);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final size = (constraints.maxWidth * 0.35).clamp(96.0, 160.0);
                          return Center(
                            child: Assets.images.logo.svg(width: size, height: size),
                          );
                        },
                      ),
                      const Gap(16),
                      Text(
                        "Добро пожаловать в ${Branding.appName}",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const Gap(8),
                      Text(
                        "Введите email, на который оформлена подписка — мы автоматически подключим её.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                        ),
                      ),
                      const Gap(24),
                      TextFormField(
                        controller: emailController,
                        focusNode: emailFocusNode,
                        autofocus: true,
                        enabled: !state.isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                        onFieldSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          labelText: "Email",
                          hintText: "name@example.com",
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: const OutlineInputBorder(),
                          errorText: errorText,
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? "";
                          if (v.isEmpty) return "Введите email";
                          // Rely on server/repo for strict validation, but
                          // reject obviously malformed input early.
                          if (!v.contains("@") || !v.contains(".")) {
                            return "Некорректный email";
                          }
                          return null;
                        },
                      ),
                      const Gap(16),
                      FilledButton.icon(
                        onPressed: state.isLoading || !hasInput.value ? null : submit,
                        icon: state.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.rocket_launch),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            state.isLoading ? "Активируем..." : "Активировать",
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                      const Gap(12),
                      if (Branding.purchaseUrl != null)
                        TextButton(
                          onPressed: state.isLoading
                              ? null
                              : () => UriUtils.tryLaunch(Uri.parse(Branding.purchaseUrl!)),
                          child: const Text("Нет подписки?"),
                        ),
                      const Gap(4),
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () {
                                // Hand off to the stock Hiddify intro flow.
                                // introCompleted stays false, so the router
                                // will keep the user on /intro until they
                                // finish the stock onboarding.
                                notifier.reset();
                                context.go('/intro');
                              },
                        child: Text(
                          "Пропустить",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
