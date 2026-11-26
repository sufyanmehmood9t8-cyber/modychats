import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'name_setup_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String _currentVerificationId;
  int _resendSeconds = 60;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        if (mounted) {
          setState(() {
            _resendSeconds--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  void _resendSmsCode() async {
    _startTimer();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: widget.resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message ?? 'Failed to resend SMS.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        codeSent: (String newVerificationId, int? newResendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = newVerificationId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A new SMS verification code has been sent!'),
                backgroundColor: AppColors.darkNavy,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resending SMS: $e')),
        );
      }
    }
  }

  void _verifyOtp() async {
    final otp = _currentOtp;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit code'),
          backgroundColor: AppColors.accentCoral,
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);

      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NameSetupScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Invalid verification code. Please check and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verification Code',
                        style: TextStyle(
                          color: AppColors.titleText,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.subtitleText,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'Enter the 6-digit SMS code sent to '),
                            TextSpan(
                              text: widget.phoneNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // 6 PIN Input Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 46,
                            height: 56,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.accentCoral,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  if (index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else {
                                    _focusNodes[index].unfocus();
                                    _verifyOtp();
                                  }
                                } else {
                                  if (index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                }
                              },
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 28),

                      // Resend Timer Row
                      Center(
                        child: _resendSeconds > 0
                            ? Text(
                                'Resend code in ${_resendSeconds}s',
                                style: const TextStyle(
                                  color: AppColors.subtitleText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : TextButton(
                                onPressed: _resendSmsCode,
                                child: const Text(
                                  'Resend SMS Code',
                                  style: TextStyle(
                                    color: AppColors.accentCoral,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                      ),

                      const Spacer(),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
