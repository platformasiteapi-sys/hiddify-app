import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/vpnpro_activation/model/activation_failure.dart';
import 'package:hiddify/features/vpnpro_activation/notifier/activation_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Compact email-activation entry point for the "Add profile" bottom sheet
/// (Phase 8 — secondary entry point).
///
/// Rationale: users who skipped email activation at first launch, or deleted
/// their profile and ended up on the home screen with no subscription, hit
/// the stock Hiddify "Add profile" sheet when they tap the connect button.
/// Giving them an email field right there (above QR / Clipboard / Manual)
/// keeps activation one tap away without forcing them back through the
/// intro flow.
///
/// Shares state with [EmailActivationPage] via [activationNotifierProvider],
/// so loading / error state are consistent. The parent bottom sheet is
/// responsible for closing itself on success (it already listens to the
/// provider — see [AddProfileModal]).
///
/// Approximate rendered height: ~64-96 px depending on error presence.
/// When computing the sheet's `initialChildSize`, parent should assume
/// [estimatedHeight] so the sheet opens at a comfortable size.
class EmailActivateRow extends HookConsumerWidget {
  const EmailActivateRow({super.key});

  /// Used by [AddProfileOptions] in its height calculation so the sheet
  /// opens tall enough to show field + button + a line of helper text.
  /// Actual rendered height may vary slightly with theme text scale.
  static const double estimatedHeight = 88.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(activationNotifierProvider);
    final notifier = ref.read(activationNotifierProvider.notifier);

    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final formKey = useMemoized(GlobalKey<FormState>.new, const []);
    final hasInput = useState(false);

    useEffect(() {
      void listener() {
        final next = controller.text.trim().isNotEmpty;
        if (next != hasInput.value) hasInput.value = next;
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, const []);

    // Resolve the last error (if any) into a single line of red text under
    // the field. We keep this compact — no two-line presentation — because
    // the sheet is short on vertical space.
    String? errorText;
    if (state is AsyncError) {
      final err = state.error;
      if (err is ActivationFailure) {
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
      await notifier.activate(controller.text);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !state.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                    onFieldSubmitted: (_) => submit(),
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: "Email для активации",
                      hintText: "name@example.com",
                      prefixIcon: Icon(Icons.alternate_email, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      // Don't show errors here — rendered below as a single
                      // line of helper text so the sheet height stays stable.
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? "";
                      if (v.isEmpty) return "";
                      if (!v.contains("@") || !v.contains(".")) return "";
                      return null;
                    },
                  ),
                ),
                const Gap(8),
                FilledButton(
                  onPressed: state.isLoading || !hasInput.value ? null : submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Активировать"),
                ),
              ],
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  errorText,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
