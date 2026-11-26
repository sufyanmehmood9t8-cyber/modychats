import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'otp_verification_screen.dart';

class CountryItem {
  final String name;
  final String code;
  final String flag;

  const CountryItem({
    required this.name,
    required this.code,
    required this.flag,
  });
}

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  final List<CountryItem> _countries = const [
    CountryItem(name: 'Pakistan', code: '+92', flag: '🇵🇰'),
    CountryItem(name: 'India', code: '+91', flag: '🇮🇳'),
    CountryItem(name: 'Saudi Arabia', code: '+966', flag: '🇸🇦'),
    CountryItem(name: 'United Arab Emirates', code: '+971', flag: '🇦🇪'),
    CountryItem(name: 'United States', code: '+1', flag: '🇺🇸'),
    CountryItem(name: 'United Kingdom', code: '+44', flag: '🇬🇧'),
  ];

  late CountryItem _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _countries[0]; // Default Pakistan
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onVerifyPressed() async {
    var rawNumber = _phoneController.text.trim();
    if (rawNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: AppColors.accentCoral,
        ),
      );
      return;
    }

    // Strip leading zeroes for valid E.164 format (e.g. 0333 -> 333)
    while (rawNumber.startsWith('0')) {
      rawNumber = rawNumber.substring(1);
    }

    final fullPhone = '${_selectedCountry.code}$rawNumber';

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution on some Android devices
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message ?? 'SMS Verification Failed. Please check phone number format or Firebase Console settings.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  phoneNumber: fullPhone,
                  verificationId: verificationId,
                  resendToken: resendToken,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Timeout reached
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error triggering SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Country',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.titleText,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    final item = _countries[index];
                    final isSelected = item.code == _selectedCountry.code;
                    return ListTile(
                      leading: Text(item.flag, style: const TextStyle(fontSize: 24)),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text(
                        item.code,
                        style: TextStyle(
                          color: isSelected ? AppColors.accentCoral : AppColors.subtitleText,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCountry = item;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                      // Header Title & Description
                      const Text(
                        'Enter Your Phone Number',
                        style: TextStyle(
                          color: AppColors.titleText,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Modychat will send a real SMS verification code to confirm your phone number.',
                        style: TextStyle(
                          color: AppColors.subtitleText,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Country Selector Row
                      GestureDetector(
                        onTap: _showCountryPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(_selectedCountry.flag, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedCountry.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.titleText,
                                  ),
                                ),
                              ),
                              Text(
                                _selectedCountry.code,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentCoral,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.subtitleText),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone Input Field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedCountry.code,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.titleText,
                                  letterSpacing: 0.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '300 1234567',
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onVerifyPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Send SMS Code',
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
