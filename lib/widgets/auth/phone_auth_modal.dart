/// Phone Authentication Modal
///
/// Custom glassmorphic modal for phone number authentication.
/// Handles both phone number input and OTP verification in a
/// beautiful, app-consistent design.
///
/// Features:
/// - Two-step flow: Phone input → OTP verification
/// - Glassmorphic design matching app aesthetics
/// - Country code selection (default: +1 US)
/// - Auto-focus and keyboard handling
/// - Firebase Phone Auth integration
/// - Comprehensive error handling
library;

import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Show phone authentication modal
///
/// Returns UserCredential if successful, null if cancelled or failed
Future<UserCredential?> showPhoneAuthModal(BuildContext context) async {
  return await showModalBottomSheet<UserCredential>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const PhoneAuthModal(),
  );
}

/// Phone authentication modal widget
class PhoneAuthModal extends StatefulWidget {
  const PhoneAuthModal({super.key});

  @override
  State<PhoneAuthModal> createState() => _PhoneAuthModalState();
}

class _PhoneAuthModalState extends State<PhoneAuthModal> {
  // ========== State Variables ==========

  /// Current authentication step
  _AuthStep _currentStep = _AuthStep.phoneInput;

  /// Phone number input controller
  final _phoneController = TextEditingController();

  /// OTP input controller
  final _otpController = TextEditingController();

  /// Selected country code
  String _countryCode = '+1';

  /// Verification ID from Firebase
  String? _verificationId;

  /// Resend token for OTP
  int? _resendToken;

  /// Loading state
  bool _isLoading = false;

  /// Error message
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ========== Phone Auth Methods ==========

  /// Submit phone number and request OTP
  Future<void> _submitPhoneNumber() async {
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final fullPhoneNumber = '$_countryCode$phoneNumber';

    developer.log(
      '📱 Submitting phone number: $fullPhoneNumber',
      name: 'PhoneAuth.Submit',
    );

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onCodeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      developer.log(
        '❌ Phone verification error',
        name: 'PhoneAuth.Error',
        error: e,
      );

      setState(() {
        _errorMessage = 'Failed to send verification code. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Auto-verification completed (instant verification)
  Future<void> _onVerificationCompleted(PhoneAuthCredential credential) async {
    developer.log(
      '✅ Auto-verification completed',
      name: 'PhoneAuth.AutoVerify',
    );

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      developer.log(
        '✅ Phone sign-in successful (auto)',
        name: 'PhoneAuth.Success',
      );

      if (mounted) {
        Navigator.of(context).pop(userCredential);
      }
    } catch (e) {
      developer.log(
        '❌ Auto-verification sign-in error',
        name: 'PhoneAuth.Error',
        error: e,
      );

      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Verification failed
  void _onVerificationFailed(FirebaseAuthException e) {
    developer.log(
      '❌ Phone verification failed: ${e.code}\n'
      '   Message: ${e.message}',
      name: 'PhoneAuth.Failed',
      error: e,
    );

    String errorMessage = 'Verification failed. Please try again.';

    switch (e.code) {
      case 'invalid-phone-number':
        errorMessage = 'Invalid phone number format';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many attempts. Please try again later.';
        break;
      case 'quota-exceeded':
        errorMessage = 'SMS quota exceeded. Please try again later.';
        break;
    }

    setState(() {
      _errorMessage = errorMessage;
      _isLoading = false;
    });
  }

  /// OTP code sent successfully
  void _onCodeSent(String verificationId, int? resendToken) {
    developer.log(
      '📨 OTP code sent\n'
      '   Verification ID: ${verificationId.substring(0, 20)}...\n'
      '   Has resend token: ${resendToken != null}',
      name: 'PhoneAuth.CodeSent',
    );

    setState(() {
      _verificationId = verificationId;
      _resendToken = resendToken;
      _currentStep = _AuthStep.otpInput;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  /// Code auto-retrieval timeout
  void _onCodeAutoRetrievalTimeout(String verificationId) {
    developer.log(
      '⏱️  Auto-retrieval timeout',
      name: 'PhoneAuth.Timeout',
    );

    setState(() => _verificationId = verificationId);
  }

  /// Verify OTP code
  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    if (_verificationId == null) {
      setState(() => _errorMessage = 'Verification session expired. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    developer.log(
      '🔐 Verifying OTP code...',
      name: 'PhoneAuth.Verify',
    );

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      developer.log(
        '✅ Phone sign-in successful\n'
        '   • UID: ${userCredential.user?.uid}\n'
        '   • Phone: ${userCredential.user?.phoneNumber}',
        name: 'PhoneAuth.Success',
      );

      if (mounted) {
        Navigator.of(context).pop(userCredential);
      }
    } on FirebaseAuthException catch (e) {
      developer.log(
        '❌ OTP verification error: ${e.code}',
        name: 'PhoneAuth.Error',
        error: e,
      );

      String errorMessage = 'Invalid verification code';

      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid code. Please check and try again.';
          break;
        case 'session-expired':
          errorMessage = 'Code expired. Please request a new code.';
          break;
      }

      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    }
  }

  /// Resend OTP code
  Future<void> _resendCode() async {
    developer.log(
      '🔄 Resending OTP code...',
      name: 'PhoneAuth.Resend',
    );

    setState(() {
      _currentStep = _AuthStep.phoneInput;
      _otpController.clear();
      _errorMessage = null;
    });

    await _submitPhoneNumber();
  }

  // ========== UI Build Methods ==========

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _currentStep == _AuthStep.phoneInput
                          ? _buildPhoneInputStep()
                          : _buildOTPInputStep(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build modal header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep == _AuthStep.otpInput)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                setState(() {
                  _currentStep = _AuthStep.phoneInput;
                  _otpController.clear();
                  _errorMessage = null;
                });
              },
            ),
          Expanded(
            child: Text(
              _currentStep == _AuthStep.phoneInput
                  ? 'Phone Sign In'
                  : 'Enter Verification Code',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Build phone number input step
  Widget _buildPhoneInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter your phone number to receive a verification code',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Phone number input
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code selector
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                _countryCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),

            // Phone number field
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
            ),
          ],
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Send code button
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPhoneNumber,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.white.withOpacity(0.3),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Send Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  /// Build OTP input step
  Widget _buildOTPInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We sent a 6-digit code to\n$_countryCode${_phoneController.text}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // OTP input field
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (value) {
            // Auto-verify when 6 digits entered
            if (value.length == 6) {
              _verifyOTP();
            }
          },
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Verify button
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.white.withOpacity(0.3),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // Resend code button
        TextButton(
          onPressed: _isLoading ? null : _resendCode,
          child: const Text(
            'Resend Code',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Authentication step enum
enum _AuthStep {
  phoneInput,
  otpInput,
}
