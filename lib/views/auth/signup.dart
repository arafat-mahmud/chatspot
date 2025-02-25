import 'package:flutter/material.dart';
import 'signin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import Timer
import 'package:email_validator/email_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // Add email controller
  final TextEditingController _passwordController = TextEditingController(); // Add password controller
  final TextEditingController _confirmPasswordController = TextEditingController(); // Add this line
  final FocusNode _passwordFocusNode = FocusNode(); // Add FocusNode for password field
  String? _selectedGender; // Variable to store selected gender

  // Add these variables to track password validation status
  bool _isUpperCaseValid = false;
  bool _isLowerCaseValid = false;
  bool _isNumberValid = false;
  bool _isSpecialCharValid = false;

  // Add a boolean variable to track password visibility
  bool _isPasswordVisible = false; // For Password field
  bool _isConfirmPasswordVisible = false; // For Confirm Password field

  // Add a Timer variable
  Timer? _verificationTimer;

  // Add a boolean variable to track email validity
  bool _isEmailInvalid = false;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {}); // Update the UI when focus changes
    });
  }

  @override
  void dispose() {
    _verificationTimer?.cancel(); // Cancel the timer
    _passwordFocusNode.dispose(); // Dispose of the FocusNode
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
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Make the most of your professional life',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[600],
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
                      _isEmailInvalid = !EmailValidator.validate(value); // Update email validity
                    }
                  });
                },
                onEditingComplete: () {
                  setState(() {
                    _isEmailInvalid = false; // Reset error when editing is complete
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
                    _dobController.text = "${pickedDate.toLocal()}".split(' ')[0];
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
                    controller: _passwordController, // Use the password controller
                    obscureText: !_isPasswordVisible, // Toggle visibility
                    focusNode: _passwordFocusNode, // Attach FocusNode
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible; // Toggle password visibility
                          });
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _isPasswordValid(value); // Validate password on change
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
                controller: _confirmPasswordController, // Use the confirm password controller
                obscureText: !_isConfirmPasswordVisible, // Toggle visibility
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible; // Toggle password visibility
                      });
                    },
                  ),
                ),
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
                  backgroundColor: Colors.blue,
                ),
                onPressed: () async {
                  // Validate required fields
                  if (_nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter your name')),
                    );
                    return; // Prevent sign-up if name is empty
                  }

                  if (_emailController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter your email')),
                    );
                    return; // Prevent sign-up if email is empty
                  }

                  if (_dobController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter your date of birth')),
                    );
                    return; // Prevent sign-up if date of birth is empty
                  }

                  if (_selectedGender == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please select a gender')),
                    );
                    return; // Prevent sign-up if no gender is selected
                  }

                  // Validate email format
                  if (!EmailValidator.validate(_emailController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid email')),
                    );
                    return; // Prevent sign-up if email is invalid
                  }

                  if (!_isPasswordValid(_passwordController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Password must include uppercase, lowercase, numbers, special characters, and be at least 6 characters long.')),
                    );
                    return; // Prevent sign-up if password is invalid
                  }

                  // Check if Password and Confirm Password match
                  if (_passwordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Passwords do not match')),
                    );
                    return; // Prevent sign-up if passwords do not match
                  }

                  try {
                    UserCredential userCredential = await FirebaseAuth.instance
                        .createUserWithEmailAndPassword(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );

                    // Send verification email
                    await userCredential.user!.sendEmailVerification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Please verify your email within 5 minutes to continue.')),
                    );

                    // Start checking email verification status
                    _startEmailVerificationCheck(userCredential.user!);

                    // Save user information to Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userCredential.user!.uid)
                        .set({
                      'name': _nameController.text,
                      'email': userCredential.user!.email,
                      'gender': _selectedGender,
                      'dob': _dobController.text,
                      'uid': userCredential.user!.uid,
                    });
                  } on FirebaseAuthException catch (e) {
                    // Handle error (e.g., show a message)
                    print('Error saving user data to Firestore: $e'); // Log the error
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save user data: $e')),
                    );
                  }
                },
                child: Text(
                  'Sign up',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Already have an account? Link
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignInPage()),
                  );
                },
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        _buildRequirement('At least one special character', _isSpecialCharValid),
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
        Text(text, style: TextStyle(color: isValid ? Colors.green : Colors.red)),
      ],
    );
  }

  // Add this method to start checking email verification status
  void _startEmailVerificationCheck(User user) {
    _verificationTimer = Timer.periodic(Duration(seconds: 300), (timer) async {
      await user.reload();
      User updatedUser = FirebaseAuth.instance.currentUser!;

      if (updatedUser.emailVerified) {
        timer.cancel();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => SignInPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please verify your email within 5 minutes to continue.')),
        );
      }
    });
  }
}
