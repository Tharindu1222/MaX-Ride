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
  final phoneCtrl = TextEditingController(text: '+94779876543');
  final otpCtrl = TextEditingController(text: '123456');
  bool otpSent = false;
  bool loading = false;
  String? message;

  Future<void> requestOtp() async {
    setState(() => loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/otp/request', {
        'phoneNumber': phoneCtrl.text.trim(),
        'userType': 'DRIVER',
      });
      setState(() {
        otpSent = true;
        message = (res['data'] as Map?)?['mockHint']?.toString();
      });
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> verify() async {
    setState(() => loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/otp/verify', {
        'phoneNumber': phoneCtrl.text.trim(),
        'code': otpCtrl.text.trim(),
        'userType': 'DRIVER',
      });
      final data = res['data'] as Map<String, dynamic>;
      await api.saveTokens(data['accessToken'], data['refreshToken']);
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
            colors: [dNavy, dInk],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text('MaX Ride',
                    style: TextStyle(color: dAmber, fontSize: 36, fontWeight: FontWeight.w800)),
                const Text('Driver', style: TextStyle(color: Colors.white70, fontSize: 20)),
                const SizedBox(height: 32),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: 'Phone')),
                if (otpSent) ...[
                  const SizedBox(height: 12),
                  TextField(controller: otpCtrl, decoration: const InputDecoration(hintText: 'OTP')),
                ],
                if (message != null) Text(message!, style: const TextStyle(color: dAmber)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: dAmber, foregroundColor: dInk),
                    onPressed: loading ? null : () => otpSent ? verify() : requestOtp(),
                    child: Text(otpSent ? 'Verify' : 'Send OTP'),
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
