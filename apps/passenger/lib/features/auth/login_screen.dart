import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final phoneCtrl = TextEditingController(text: '+94771234567');
  final otpCtrl = TextEditingController(text: '123456');
  bool otpSent = false;
  bool loading = false;
  String? message;

  @override
  void dispose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    super.dispose();
  }

  Future<void> requestOtp() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/otp/request', {
        'phoneNumber': phoneCtrl.text.trim(),
        'userType': 'PASSENGER',
      });
      setState(() {
        otpSent = true;
        message = (res['data'] as Map?)?['mockHint']?.toString() ??
            'Code sent to your phone';
      });
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> verifyOtp() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/otp/verify', {
        'phoneNumber': phoneCtrl.text.trim(),
        'code': otpCtrl.text.trim(),
        'userType': 'PASSENGER',
      });
      final data = res['data'] as Map<String, dynamic>;
      await api.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      if (!mounted) return;
      context.go('/select');
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pcBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 1.1,
                colors: [
                  pcWine.withValues(alpha: 0.28),
                  pcBlack,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.go('/welcome'),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: pcWhite.withValues(alpha: 0.85),
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  Image.asset(
                    'assets/images/pcablogo.png',
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Continue with mobile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pcWhite.withValues(alpha: 0.95),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We’ll text you a one-time code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pcWhite.withValues(alpha: 0.55),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: pcWhite.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: pcBlack.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: maxInk,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            hintText: '+94 77 123 4567',
                          ),
                        ),
                        if (otpSent) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: maxInk,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'One-time code',
                              hintText: '6-digit code',
                            ),
                          ),
                        ],
                        if (message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            message!,
                            style: TextStyle(
                              color: pcWine.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: loading
                              ? null
                              : () => otpSent ? verifyOtp() : requestOtp(),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(48, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            loading
                                ? 'Please wait…'
                                : otpSent
                                    ? 'Verify & continue'
                                    : 'Send code',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  Text(
                    'Sri Lanka · LKR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pcWhite.withValues(alpha: 0.35),
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
