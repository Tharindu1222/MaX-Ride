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
      context.go('/');
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [maxForest, Color(0xFF163A2F), maxInk],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: maxLime.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Sri Lanka · LKR',
                    style: TextStyle(
                      color: maxLime,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'MaX Ride',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Get a tuk, car, or van in a few taps.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: maxSurface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: maxShadowSoft,
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
                          style: const TextStyle(
                            color: maxForest,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: loading
                            ? null
                            : () => otpSent ? verifyOtp() : requestOtp(),
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
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
