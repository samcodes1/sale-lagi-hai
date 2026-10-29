import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/failure_messages.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/domain/phone_number.dart';

/// How long before a new code may be requested.
const resendWait = Duration(seconds: 60);

/// Optional sign-in (UX flow F6): a Pakistani mobile number and a texted
/// code, or Google. Pops `true` once signed in.
///
/// [reauth]: signing in again before a sensitive action (account
/// deletion). The number is prefilled for phone users.
class SignInScreen extends ConsumerStatefulWidget {
  const new({this.reauth = false, super.key});

  final bool reauth;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  /// The number a code was sent to; `null` on the phone step.
  String? _sentTo;
  bool _busy = false;
  String? _phoneError;
  String? _codeError;
  AppFailure? _failure;
  Timer? _ticker;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    final phone = user?.phone;
    if (widget.reauth && phone != null) {
      // "+92 300 1234567" → "300 1234567"
      _phone.text = PakistanPhone.display(phone).substring(4);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _ticker?.cancel();
    setState(() => _resendIn = resendWait.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    final l10n = context.l10n;
    final e164 = PakistanPhone.toE164(_phone.text);
    if (e164 == null) {
      setState(() => _phoneError = l10n.phoneInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _phoneError = null;
      _failure = null;
    });
    final result = await ref.read(authRepositoryProvider).sendPhoneCode(e164);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success():
        setState(() {
          _sentTo = e164;
          _code.clear();
          _codeError = null;
        });
        _startResendTimer();
        _codeFocus.requestFocus();
      case Failure(failure: ValidationFailure()):
        setState(() => _phoneError = l10n.phoneInvalid);
      case Failure(:final failure):
        setState(() => _failure = failure);
    }
  }

  Future<void> _verify() async {
    final sentTo = _sentTo;
    final code = _code.text;
    if (sentTo == null || code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _codeError = null;
      _failure = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .verifyPhoneCode(sentTo, code);
    if (!mounted) return;
    switch (result) {
      case Success():
        await _signedIn();
      case Failure(failure: ValidationFailure()):
        setState(() {
          _busy = false;
          _codeError = context.l10n.codeInvalid;
        });
      case Failure(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (!mounted) return;
    switch (result) {
      case Success(value: null):
        setState(() => _busy = false); // closed the Google sheet
      case Success():
        await _signedIn();
      case Failure(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  Future<void> _signedIn() async {
    if (!widget.reauth) await ref.read(guestSyncProvider)();
    if (!mounted) return;
    if (!widget.reauth) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.signedInToast)));
    }
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canUseGoogle = ref.watch(authRepositoryProvider).canUseGoogle;
    final sentTo = _sentTo;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        // Not a lazy list: the whole (short) form is built, so focusing a
        // field below the fold at large text sizes works.
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  sentTo != null
                      ? l10n.codeTitle
                      : widget.reauth
                      ? l10n.reauthTitle
                      : l10n.signInTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: BrandSpacing.s3),
              Text(
                sentTo != null
                    ? l10n.codeSentTo(PakistanPhone.display(sentTo))
                    : widget.reauth
                    ? l10n.reauthBody
                    : l10n.signInBody,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: BrandSpacing.s7),
              if (sentTo == null)
                ..._phoneStep(l10n, canUseGoogle)
              else
                ..._codeStep(l10n),
              if (_failure case final failure?) ...[
                const SizedBox(height: BrandSpacing.s5),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    failure.message(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (!widget.reauth) ...[
                const SizedBox(height: BrandSpacing.s8),
                Text(l10n.signInTerms, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(AppLocalizations l10n, bool canUseGoogle) => [
    TextField(
      controller: _phone,
      enabled: !_busy,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.send,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      // Numbers read left to right in both languages.
      textDirection: TextDirection.ltr,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-۰-۹٠-٩]')),
        LengthLimitingTextInputFormatter(17),
      ],
      decoration: InputDecoration(
        labelText: l10n.phoneLabel,
        hintText: l10n.phoneHint,
        hintTextDirection: Directionality.of(context),
        errorText: _phoneError,
        errorMaxLines: 3,
        prefixIcon: const Icon(Icons.phone_android),
      ),
      onSubmitted: (_) => _sendCode(),
    ),
    const SizedBox(height: BrandSpacing.s5),
    FilledButton(
      onPressed: _busy ? null : _sendCode,
      child: Text(l10n.actionSendCode),
    ),
    if (canUseGoogle) ...[
      const SizedBox(height: BrandSpacing.s5),
      Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BrandSpacing.s4,
            ),
            child: Text(l10n.signInOr),
          ),
          const Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: BrandSpacing.s5),
      OutlinedButton.icon(
        onPressed: _busy ? null : _google,
        icon: const Icon(Icons.account_circle_outlined),
        label: Text(l10n.actionContinueWithGoogle),
      ),
    ],
  ];

  List<Widget> _codeStep(AppLocalizations l10n) => [
    TextField(
      controller: _code,
      focusNode: _codeFocus,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      // The SMS code autofills; pasting works; nothing is learnt or
      // suggested from it.
      autofillHints: const [AutofillHints.oneTimeCode],
      enableSuggestions: false,
      autocorrect: false,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(letterSpacing: 8),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: l10n.codeLabel,
        errorText: _codeError,
        errorMaxLines: 3,
      ),
      onChanged: (value) {
        if (value.length == 6) unawaited(_verify());
      },
      onSubmitted: (_) => _verify(),
    ),
    const SizedBox(height: BrandSpacing.s5),
    if (_busy)
      const Center(child: CircularProgressIndicator())
    else
      Wrap(
        spacing: BrandSpacing.s3,
        runSpacing: BrandSpacing.s2,
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _sentTo = null;
              _ticker?.cancel();
            }),
            child: Text(l10n.actionChangeNumber),
          ),
          if (_resendIn > 0)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BrandSpacing.s4,
              ),
              child: Text(l10n.resendIn(_resendIn)),
            )
          else
            TextButton(
              onPressed: _sendCode,
              child: Text(l10n.actionResendCode),
            ),
        ],
      ),
  ];
}
