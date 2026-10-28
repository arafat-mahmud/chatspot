import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_validator/email_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:loading_animation_widget/loading_animation_widget.dart'; // Import loading animation

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController(); // Add email controller
  final TextEditingController _passwordController =
      TextEditingController(); // Add password controller
  final TextEditingController _confirmPasswordController =
      TextEditingController(); // Add this line
  final FocusNode _passwordFocusNode =
      FocusNode(); // Add FocusNode for password field
  String? _selectedGender; // Variable to store selected gender

  // Add these variables to track password validation status
  bool _isUpperCaseValid = false;
  bool _isLowerCaseValid = false;
  bool _isNumberValid = false;
  bool _isSpecialCharValid = false;

  // Add a boolean variable to track password visibility
  bool _isPasswordVisible = false; // For Password field
  bool _isConfirmPasswordVisible = false; // For Confirm Password field

  bool _isLoading = false;

  // Add a boolean variable to track email validity
  bool _isEmailInvalid = false;

  // Add a boolean variable to track password match
  bool _passwordsMatch = true;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {}); // Update the UI when focus changes
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Sign up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Make the most of your professional life',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 32),

              // Name Field
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Email Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  errorText: _isEmailInvalid && _emailController.text.isNotEmpty
                      ? 'Invalid email format'
                      : null, // Real-time feedback
                ),
                onChanged: (value) {
                  setState(() {
                    // Only validate if the input is not empty
                    if (value.isEmpty) {
                      _isEmailInvalid = false; // No error for empty input
                    } else {
                      _isEmailInvalid = !EmailValidator.validate(
                          value); // Update email validity
                    }
                  });
                },
                onEditingComplete: () {
                  setState(() {
                    _isEmailInvalid =
                        false; // Reset error when editing is complete
                  });
                },
              ),
              SizedBox(height: 16),

              // Date of Birth Field
              TextField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    _dobController.text =
                        "${pickedDate.toLocal()}".split(' ')[0];
                  }
                },
              ),
              SizedBox(height: 16),

              // Gender Field
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value; // Update selected gender
                  });
                },
              ),
              SizedBox(height: 16),

              // Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller:
                        _passwordController, // Use the password controller
                    obscureText: !_isPasswordVisible, // Toggle visibility
                    focusNode: _passwordFocusNode, // Attach FocusNode
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible =
                                !_isPasswordVisible; // Toggle password visibility
                          });
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _isPasswordValid(value); // Validate password on change
                        // Check if confirm password matches when password changes
                        if (_confirmPasswordController.text.isNotEmpty) {
                          _passwordsMatch =
                              _confirmPasswordController.text == value;
                        }
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  // Show password requirements only if the password field is focused
                  if (_passwordFocusNode.hasFocus) _buildPasswordRequirements(),
                ],
              ),
              SizedBox(height: 8),

              // Confirm Password Field
              TextField(
                controller:
                    _confirmPasswordController, // Use the confirm password controller
                obscureText: !_isConfirmPasswordVisible, // Toggle visibility
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  errorText: !_passwordsMatch &&
                          _confirmPasswordController.text.isNotEmpty
                      ? 'Passwords do not match'
                      : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible =
                            !_isConfirmPasswordVisible; // Toggle password visibility
                      });
                    },
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _passwordsMatch =
                        value.isEmpty || value == _passwordController.text;
                  });
                },
                onTap: () {
                  // When the Confirm Password field is tapped, unfocus the password field
                  _passwordFocusNode.unfocus();
                },
              ),
              SizedBox(height: 16),

              // Sign-Up Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.white,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]!
                        : Colors.grey,
                  ),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? LoadingAnimationWidget.threeRotatingDots(
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      )
                    : Text(
                        'Sign up',
                        style: TextStyle(fontSize: 16.0),
                      ),
              ),
              SizedBox(height: 16),

              // Already have an account? Link
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? problem;
    if (name.length < 2) {
      problem = 'Please enter your name';
    } else if (!EmailValidator.validate(email)) {
      problem = 'Please enter a valid email';
    } else if (!_isPasswordValid(password)) {
      problem = "Password doesn't meet the requirements below";
    } else if (password != _confirmPasswordController.text) {
      _passwordsMatch = false;
      problem = 'Passwords do not match';
    }
    if (problem != null) {
      setState(() {});
      _showError(problem);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user!;
      await Future.wait([
        user.sendEmailVerification(),
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'nameLower': name.toLowerCase(),
          'email': user.email,
          'gender': _selectedGender,
          'dob': _dobController.text,
          'uid': user.uid,
          'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);
      // Unverified accounts don't get into the app; they sign in after
      // opening the link.
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined, size: 40),
          title: const Text('Verify your email'),
          content: Text(
              'We sent a verification link to $email. Open it, then sign in.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go to sign in'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).maybePop();
    } on FirebaseAuthException catch (e) {
      _showError(switch (e.code) {
        'email-already-in-use' =>
          'An account with this email already exists. Try signing in.',
        'invalid-email' => 'Please enter a valid email',
        'weak-password' => 'Please choose a stronger password',
        'network-request-failed' => 'No internet connection',
        _ => 'Sign up failed. Please try again.',
      });
    } catch (e) {
      debugPrint('Sign up failed: $e');
      _showError('Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // Update the _isPasswordValid method to set the validation status
  bool _isPasswordValid(String password) {
    _isUpperCaseValid = RegExp(r'[A-Z]').hasMatch(password);
    _isLowerCaseValid = RegExp(r'[a-z]').hasMatch(password);
    _isNumberValid = RegExp(r'[0-9]').hasMatch(password);
    _isSpecialCharValid = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return _isUpperCaseValid &&
        _isLowerCaseValid &&
        _isNumberValid &&
        _isSpecialCharValid &&
        password.length >= 6;
  }

  // Add this method to build the password requirements list
  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password Requirements:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        _buildRequirement(
            '6 to 32 characters',
            _passwordController.text.length >= 6 &&
                _passwordController.text.length <= 32),
        _buildRequirement('At least one uppercase letter', _isUpperCaseValid),
        _buildRequirement('At least one lowercase letter', _isLowerCaseValid),
        _buildRequirement('At least one number', _isNumberValid),
        _buildRequirement(
            'At least one special character', _isSpecialCharValid),
      ],
    );
  }

  // Helper method to build individual requirement
  Widget _buildRequirement(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check : Icons.close,
          color: isValid ? Colors.green : Colors.red,
        ),
        SizedBox(width: 8),
        Text(text,
            style: TextStyle(color: isValid ? Colors.green : Colors.red)),
      ],
    );
  }
}
