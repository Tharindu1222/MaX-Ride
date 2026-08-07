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
        message = (res['data'] as Map?)?['mockHint']?.toString() ?? 'OTP sent';
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
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  'MaX Ride',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: maxLime,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sri Lanka, on your time.\nCash or card · LKR',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: maxInk),
                  decoration: const InputDecoration(hintText: 'Mobile number'),
                ),
                if (otpSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: maxInk),
                    decoration: const InputDecoration(hintText: 'OTP (mock: 123456)'),
                  ),
                ],
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(message!, style: const TextStyle(color: maxLime)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () => otpSent ? verifyOtp() : requestOtp(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maxLime,
                      foregroundColor: maxInk,
                    ),
                    child: Text(loading
                        ? 'Please wait…'
                        : otpSent
                            ? 'Verify & continue'
                            : 'Send OTP'),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
