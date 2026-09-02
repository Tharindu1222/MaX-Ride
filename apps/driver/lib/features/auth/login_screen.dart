import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    setState(() {
      loading = true;
      message = null;
    });
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

  bool get _isError =>
      message != null &&
      (message!.startsWith('Exception') || message!.toLowerCase().contains('error'));

  InputDecoration _field(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: dBlack.withValues(alpha: 0.38)),
      filled: true,
      fillColor: dWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: dGreen, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      color: dWhite,
      height: 1.02,
      letterSpacing: -1.1,
    );

    return Scaffold(
      backgroundColor: dBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/driver_hero_car_tight.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.42),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE60A0A0A),
                  Color(0x660A0A0A),
                  Color(0x220A0A0A),
                  Color(0xF20A0A0A),
                ],
                stops: [0.0, 0.22, 0.48, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: dBlack,
                        shape: CircleBorder(
                          side: BorderSide(color: dWhite.withValues(alpha: 0.18)),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.go('/welcome'),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.arrow_back_ios_new, color: dWhite, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: dBlack,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: dWhite.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: dGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'MaX Ride  ·  Driver',
                              style: GoogleFonts.inter(
                                color: dWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    otpSent ? 'Enter the' : 'Enter your',
                    style: titleStyle.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    otpSent ? 'OTP Code' : 'Number',
                    style: titleStyle.copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: dGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    otpSent
                        ? 'Enter the code we sent you.'
                        : 'Enter your mobile number to continue.',
                    style: GoogleFonts.inter(
                      color: dWhite.withValues(alpha: 0.82),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: dBlack,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: dWhite.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: phoneCtrl,
                          enabled: !otpSent && !loading,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(
                            color: dBlack,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          cursorColor: dGreen,
                          decoration: _field('Mobile number').copyWith(
                            labelText: 'Mobile number',
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                          ),
                        ),
                        if (otpSent) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: otpCtrl,
                            enabled: !loading,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(
                              color: dBlack,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            cursorColor: dGreen,
                            decoration: _field('OTP code'),
                          ),
                        ],
                        if (message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            message!,
                            style: GoogleFonts.inter(
                              color: _isError ? const Color(0xFFFFB4AB) : dGreen,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dGreen,
                              foregroundColor: dBlack,
                              disabledBackgroundColor: dGreen.withValues(alpha: 0.45),
                              disabledForegroundColor: dBlack.withValues(alpha: 0.55),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: loading ? null : () => otpSent ? verify() : requestOtp(),
                            child: loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: dBlack,
                                    ),
                                  )
                                : Text(
                                    otpSent ? 'Verify' : 'Send OTP',
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        if (otpSent)
                          Center(
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () => setState(() {
                                        otpSent = false;
                                        message = null;
                                      }),
                              child: Text(
                                'Change number',
                                style: GoogleFonts.inter(
                                  color: dWhite.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
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
